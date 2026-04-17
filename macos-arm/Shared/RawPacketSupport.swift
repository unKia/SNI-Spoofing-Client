import Foundation

enum PcapDataLink: Equatable {
    case ethernet
    case rawIPv4
    case nullLoopback
    case unknown(Int32)

    init(rawValue: Int32) {
        switch rawValue {
        case 1:
            self = .ethernet
        case 0:
            self = .nullLoopback
        case 12:
            self = .rawIPv4
        default:
            self = .unknown(rawValue)
        }
    }

    var description: String {
        switch self {
        case .ethernet:
            return "DLT_EN10MB(1)"
        case .rawIPv4:
            return "DLT_RAW(12)"
        case .nullLoopback:
            return "DLT_NULL(0)"
        case let .unknown(value):
            return "UNKNOWN(\(value))"
        }
    }
}

struct ParsedEthernetIPv4TCPFrame {
    let rawData: Data
    let linkType: PcapDataLink
    let linkHeaderLength: Int
    let ipStart: Int
    let tcpStart: Int
    let ipHeaderLength: Int
    let tcpHeaderLength: Int
    let sourceIP: String
    let destinationIP: String
    let sourcePort: UInt16
    let destinationPort: UInt16
    let sequenceNumber: UInt32
    let acknowledgementNumber: UInt32
    let flags: UInt8
    let payload: Data

    var payloadStart: Int {
        tcpStart + tcpHeaderLength
    }

    var syn: Bool { flags & 0x02 != 0 }
    var ack: Bool { flags & 0x10 != 0 }
    var fin: Bool { flags & 0x01 != 0 }
    var rst: Bool { flags & 0x04 != 0 }
}

enum RawPacketSupport {
    static func parseIPv4TCPFrame(_ frame: Data, linkType: PcapDataLink) -> ParsedEthernetIPv4TCPFrame? {
        switch linkType {
        case .ethernet:
            return parseEthernetIPv4TCPFrame(frame)
        case .rawIPv4:
            return parseFrame(frame, linkType: linkType, ipStart: 0, linkHeaderLength: 0)
        case .nullLoopback:
            return parseNullLoopbackIPv4TCPFrame(frame)
        case .unknown:
            return nil
        }
    }

    static func buildFakePayloadFrame(from frame: ParsedEthernetIPv4TCPFrame, fakePayload: Data, forcedSequenceNumber: UInt32) -> Data {
        var bytes = [UInt8](frame.rawData[0 ..< frame.payloadStart])
        bytes.append(contentsOf: fakePayload)

        let totalLength = UInt16(frame.ipHeaderLength + frame.tcpHeaderLength + fakePayload.count)
        writeUInt16(totalLength, into: &bytes, offset: frame.ipStart + 2)

        let currentIdentification = readUInt16(Data(bytes), offset: frame.ipStart + 4)
        writeUInt16(currentIdentification &+ 1, into: &bytes, offset: frame.ipStart + 4)
        writeUInt16(0, into: &bytes, offset: frame.ipStart + 10)

        writeUInt32(forcedSequenceNumber, into: &bytes, offset: frame.tcpStart + 4)
        bytes[frame.tcpStart + 13] = 0x18
        writeUInt16(0, into: &bytes, offset: frame.tcpStart + 16)

        let ipChecksum = checksum(bytes[frame.ipStart ..< (frame.ipStart + frame.ipHeaderLength)])
        writeUInt16(ipChecksum, into: &bytes, offset: frame.ipStart + 10)

        let tcpChecksum = tcpChecksum(for: bytes, frame: frame)
        writeUInt16(tcpChecksum, into: &bytes, offset: frame.tcpStart + 16)

        return Data(bytes)
    }

    private static func parseEthernetIPv4TCPFrame(_ frame: Data) -> ParsedEthernetIPv4TCPFrame? {
        let ethernetHeaderLength = 14
        guard frame.count >= ethernetHeaderLength + 20 + 20 else {
            return nil
        }

        let etherType = readUInt16(frame, offset: 12)
        guard etherType == 0x0800 else {
            return nil
        }

        return parseFrame(frame, linkType: .ethernet, ipStart: ethernetHeaderLength, linkHeaderLength: ethernetHeaderLength)
    }

    private static func parseNullLoopbackIPv4TCPFrame(_ frame: Data) -> ParsedEthernetIPv4TCPFrame? {
        let headerLength = 4
        guard frame.count >= headerLength + 20 + 20 else {
            return nil
        }

        let familyLittle = UInt32(frame[0])
            | UInt32(frame[1]) << 8
            | UInt32(frame[2]) << 16
            | UInt32(frame[3]) << 24
        let familyBig = UInt32(frame[3])
            | UInt32(frame[2]) << 8
            | UInt32(frame[1]) << 16
            | UInt32(frame[0]) << 24

        guard familyLittle == 2 || familyBig == 2 else {
            return nil
        }

        return parseFrame(frame, linkType: .nullLoopback, ipStart: headerLength, linkHeaderLength: headerLength)
    }

    private static func parseFrame(_ frame: Data, linkType: PcapDataLink, ipStart: Int, linkHeaderLength: Int) -> ParsedEthernetIPv4TCPFrame? {
        guard frame.count >= ipStart + 20 + 20 else {
            return nil
        }

        let version = frame[ipStart] >> 4
        guard version == 4 else {
            return nil
        }

        let ipHeaderLength = Int(frame[ipStart] & 0x0f) * 4
        guard frame.count >= ipStart + ipHeaderLength + 20 else {
            return nil
        }

        guard frame[ipStart + 9] == 6 else {
            return nil
        }

        let sourceIP = ipv4String(from: frame[(ipStart + 12) ..< (ipStart + 16)])
        let destinationIP = ipv4String(from: frame[(ipStart + 16) ..< (ipStart + 20)])
        let tcpStart = ipStart + ipHeaderLength
        let sourcePort = readUInt16(frame, offset: tcpStart)
        let destinationPort = readUInt16(frame, offset: tcpStart + 2)
        let sequenceNumber = readUInt32(frame, offset: tcpStart + 4)
        let acknowledgementNumber = readUInt32(frame, offset: tcpStart + 8)
        let tcpHeaderLength = Int((frame[tcpStart + 12] >> 4) * 4)
        guard frame.count >= tcpStart + tcpHeaderLength else {
            return nil
        }

        let payloadStart = tcpStart + tcpHeaderLength
        let payload = payloadStart < frame.count ? frame.subdata(in: payloadStart ..< frame.count) : Data()

        return ParsedEthernetIPv4TCPFrame(
            rawData: frame,
            linkType: linkType,
            linkHeaderLength: linkHeaderLength,
            ipStart: ipStart,
            tcpStart: tcpStart,
            ipHeaderLength: ipHeaderLength,
            tcpHeaderLength: tcpHeaderLength,
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            sequenceNumber: sequenceNumber,
            acknowledgementNumber: acknowledgementNumber,
            flags: frame[tcpStart + 13],
            payload: payload
        )
    }

    private static func tcpChecksum(for bytes: [UInt8], frame: ParsedEthernetIPv4TCPFrame) -> UInt16 {
        let tcpLength = UInt16(bytes.count - frame.tcpStart)
        var pseudoHeader = [UInt8]()
        pseudoHeader.append(contentsOf: bytes[(frame.ipStart + 12) ..< (frame.ipStart + 20)])
        pseudoHeader.append(0)
        pseudoHeader.append(6)
        pseudoHeader.append(UInt8(tcpLength >> 8))
        pseudoHeader.append(UInt8(tcpLength & 0xff))
        pseudoHeader.append(contentsOf: bytes[frame.tcpStart ..< bytes.count])
        return checksum(pseudoHeader[0 ..< pseudoHeader.count])
    }

    private static func checksum<S: Collection>(_ bytes: S) -> UInt16 where S.Element == UInt8 {
        var sum: UInt32 = 0
        var iterator = bytes.makeIterator()

        while let high = iterator.next() {
            let low = iterator.next() ?? 0
            sum += UInt32(high) << 8 | UInt32(low)
            while (sum >> 16) != 0 {
                sum = (sum & 0xffff) + (sum >> 16)
            }
        }

        return ~UInt16(sum & 0xffff)
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func writeUInt16(_ value: UInt16, into bytes: inout [UInt8], offset: Int) {
        bytes[offset] = UInt8((value >> 8) & 0xff)
        bytes[offset + 1] = UInt8(value & 0xff)
    }

    private static func writeUInt32(_ value: UInt32, into bytes: inout [UInt8], offset: Int) {
        bytes[offset] = UInt8((value >> 24) & 0xff)
        bytes[offset + 1] = UInt8((value >> 16) & 0xff)
        bytes[offset + 2] = UInt8((value >> 8) & 0xff)
        bytes[offset + 3] = UInt8(value & 0xff)
    }

    private static func ipv4String(from bytes: Data.SubSequence) -> String {
        bytes.map(String.init).joined(separator: ".")
    }
}
