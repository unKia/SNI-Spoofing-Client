import Foundation

struct ResolvedInterface: Equatable {
    let name: String
    let index: UInt32
    let ipv4Address: String
}

enum SystemNetworkError: LocalizedError {
    case invalidIPv4(String)
    case socketCreateFailed(String)
    case connectFailed(String)
    case getsocknameFailed(String)
    case interfaceNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .invalidIPv4(value):
            return "Invalid IPv4 address: \(value)"
        case let .socketCreateFailed(message):
            return "Failed to create socket: \(message)"
        case let .connectFailed(message):
            return "Probe connect failed: \(message)"
        case let .getsocknameFailed(message):
            return "getsockname failed: \(message)"
        case let .interfaceNotFound(message):
            return "Interface not found: \(message)"
        }
    }
}

enum SystemNetworkUtils {
    static func resolveInterface(forRemoteIPv4 remoteIPv4: String, remotePort: UInt16) throws -> ResolvedInterface {
        var remoteAddress = try sockaddrIn(ipv4: remoteIPv4, port: remotePort)
        let socketFD = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw SystemNetworkError.socketCreateFailed(errnoDescription())
        }
        defer {
            Darwin.close(socketFD)
        }

        let connectResult = withUnsafePointer(to: &remoteAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else {
            throw SystemNetworkError.connectFailed(errnoDescription())
        }

        var localAddress = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &localAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.getsockname(socketFD, sockaddrPointer, &addressLength)
            }
        }
        guard nameResult == 0 else {
            throw SystemNetworkError.getsocknameFailed(errnoDescription())
        }

        let localIPv4 = try string(from: localAddress)
        guard let interface = interfaceForIPv4(localIPv4) else {
            throw SystemNetworkError.interfaceNotFound(localIPv4)
        }
        return interface
    }

    static func resolveBypassInterface(forRemoteIPv4 remoteIPv4: String, remotePort: UInt16) throws -> ResolvedInterface {
        let routed = try resolveInterface(forRemoteIPv4: remoteIPv4, remotePort: remotePort)
        if !isTunnelInterfaceName(routed.name) {
            return routed
        }
        if let fallback = firstUsableNonTunnelInterface() {
            return fallback
        }
        return routed
    }

    static func sockaddrIn(ipv4: String, port: UInt16) throws -> sockaddr_in {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian

        let conversion = ipv4.withCString { cString in
            inet_pton(AF_INET, cString, &address.sin_addr)
        }
        guard conversion == 1 else {
            throw SystemNetworkError.invalidIPv4(ipv4)
        }
        return address
    }

    static func string(from address: sockaddr_in) throws -> String {
        var copy = address
        return try withUnsafePointer(to: &copy) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    sockaddrPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                guard result == 0 else {
                    throw SystemNetworkError.getsocknameFailed(String(cString: gai_strerror(result)))
                }
                return String(cString: hostBuffer)
            }
        }
    }

    static func interfaceForIPv4(_ ipv4: String) -> ResolvedInterface? {
        allIPv4Interfaces().first(where: { $0.ipv4Address == ipv4 })
    }

    static func firstUsableNonTunnelInterface() -> ResolvedInterface? {
        let interfaces = allIPv4Interfaces().filter { interface in
            !isTunnelInterfaceName(interface.name) && interface.name != "lo0"
        }

        if let preferred = interfaces.first(where: { $0.name == "en0" }) {
            return preferred
        }

        if let preferred = interfaces.first(where: { $0.name.hasPrefix("en") }) {
            return preferred
        }

        return interfaces.first
    }

    static func bindSocketToInterface(_ socketFD: Int32, interface: ResolvedInterface) throws {
        var index = Int32(interface.index)
        let result = Darwin.setsockopt(
            socketFD,
            IPPROTO_IP,
            IP_BOUND_IF,
            &index,
            socklen_t(MemoryLayout<Int32>.size)
        )
        guard result == 0 else {
            throw SystemNetworkError.connectFailed("IP_BOUND_IF failed: \(errnoDescription())")
        }
    }

    static func isTunnelInterfaceName(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.hasPrefix("tun")
    }

    private static func allIPv4Interfaces() -> [ResolvedInterface] {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            return []
        }
        defer {
            freeifaddrs(addresses)
        }

        var result: [ResolvedInterface] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let interface = current.pointee
            defer {
                cursor = interface.ifa_next
            }

            guard let sockaddrPointer = interface.ifa_addr, sockaddrPointer.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let localIPv4: String? = withUnsafePointer(to: sockaddrPointer.pointee) { pointer in
                pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ipv4Pointer in
                    try? string(from: ipv4Pointer.pointee)
                }
            }

            guard let localIPv4 else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            let index = if_nametoindex(interface.ifa_name)
            guard index != 0 else {
                continue
            }
            result.append(ResolvedInterface(name: name, index: index, ipv4Address: localIPv4))
        }

        return result
    }

    static func errnoDescription() -> String {
        String(cString: strerror(errno))
    }
}
