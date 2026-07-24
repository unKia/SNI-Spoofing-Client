import Foundation

@main
struct SniProxyHelperMain {
    static func main() {
        do {
            let options = try HelperOptions.parse(arguments: CommandLine.arguments)
            if options.showHelp {
                print(HelperOptions.usageText)
                return
            }
            if geteuid() != 0 {
                fputs("This helper must be run with sudo/root.\n", stderr)
                Foundation.exit(1)
            }

            let configuration = try options.loadConfiguration()
            print("SNI proxy helper starting on \(configuration.listenHost):\(configuration.listenPort)")
            print("target=\(configuration.connectIP):\(configuration.connectPort) fakeSNI=\(configuration.fakeSNI)")
            print("logLevel=\(configuration.logLevel.rawValue)")

            let semaphore = DispatchSemaphore(value: 0)
            let proxySnapshotStore = ProxySnapshotStore()
            let service = LocalProxyService { status in
                let shouldEmitProxyStatus = proxySnapshotStore.shouldEmit(
                    phase: status.phase,
                    connections: status.activeConnections,
                    uploadedBytes: status.bytesUploaded,
                    downloadedBytes: status.bytesDownloaded
                )

                guard shouldEmitProxyStatus || status.logLevel.priority >= configuration.logLevel.priority else {
                    return
                }
                let detail = status.detail ?? "-"
                let interfaceText: String
                if let interfaceName = status.interfaceName, let interfaceIPv4 = status.interfaceIPv4 {
                    interfaceText = "\(interfaceName)(\(interfaceIPv4))"
                } else {
                    interfaceText = "-"
                }
                print("[\(status.logLevel.rawValue)] [proxy] phase=\(status.phase) connections=\(status.activeConnections) bytesUp=\(status.bytesUploaded) bytesDown=\(status.bytesDownloaded) iface=\(interfaceText) detail=\(detail)")
                fflush(stdout)
                proxySnapshotStore.store(
                    phase: status.phase,
                    connections: status.activeConnections,
                    uploadedBytes: status.bytesUploaded,
                    downloadedBytes: status.bytesDownloaded
                )
            }

            signal(SIGINT, SIG_IGN)
            signal(SIGTERM, SIG_IGN)

            let signalQueue = DispatchQueue(label: "com.local.sni.macos.helper.signals")
            let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
            interruptSource.setEventHandler {
                print("SIGINT received, stopping helper...")
                service.stop()
                semaphore.signal()
            }
            interruptSource.resume()

            let terminateSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
            terminateSource.setEventHandler {
                print("SIGTERM received, stopping helper...")
                service.stop()
                semaphore.signal()
            }
            terminateSource.resume()

            try service.start(configuration: configuration)
            print("Helper is ready. Press Ctrl+C to stop.")
            semaphore.wait()
        } catch let error as HelperUsageError {
            fputs("\(error.localizedDescription)\n", stderr)
            fputs(HelperOptions.usageText + "\n", stderr)
            Foundation.exit(2)
        } catch {
            fputs("Helper failed: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}

private final class ProxySnapshotStore {
    private typealias Snapshot = (phase: String, connections: Int, up: Int, down: Int)

    private let lock = NSLock()
    private var snapshot: Snapshot?

    func shouldEmit(phase: String, connections: Int, uploadedBytes: Int, downloadedBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let snapshot else {
            return true
        }

        return snapshot.phase != phase ||
            snapshot.connections != connections ||
            snapshot.up != uploadedBytes ||
            snapshot.down != downloadedBytes
    }

    func store(phase: String, connections: Int, uploadedBytes: Int, downloadedBytes: Int) {
        lock.lock()
        snapshot = (
            phase: phase,
            connections: connections,
            up: uploadedBytes,
            down: downloadedBytes
        )
        lock.unlock()
    }
}

private enum HelperUsageError: LocalizedError {
    case missingValue(String)
    case invalidArgument(String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case let .invalidArgument(argument):
            return "Unknown argument: \(argument)"
        }
    }
}

private struct HelperOptions {
    let showHelp: Bool
    let configPath: String?
    let listenHost: String?
    let listenPort: Int?
    let connectIP: String?
    let connectPort: Int?
    let fakeSNI: String?
    let logLevel: ProxyLogLevel?

    static let usageText = """
    Usage:
      sudo ./sni-proxy-helper --config /path/to/config.json
      sudo ./sni-proxy-helper --listen-host 0.0.0.0 --listen-port <dynamic-port> --connect-ip 104.19.229.21 --connect-port 443 --fake-sni hcaptcha.com --log-level info
    """

    static func parse(arguments: [String]) throws -> HelperOptions {
        var showHelp = false
        var configPath: String?
        var listenHost: String?
        var listenPort: Int?
        var connectIP: String?
        var connectPort: Int?
        var fakeSNI: String?
        var logLevel: ProxyLogLevel?

        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--config":
                guard let value = iterator.next() else {
                    throw HelperUsageError.missingValue(argument)
                }
                configPath = value
            case "--listen-host":
                guard let value = iterator.next() else {
                    throw HelperUsageError.missingValue(argument)
                }
                listenHost = value
            case "--listen-port":
                guard let value = iterator.next(), let parsed = Int(value) else {
                    throw HelperUsageError.missingValue(argument)
                }
                listenPort = parsed
            case "--connect-ip":
                guard let value = iterator.next() else {
                    throw HelperUsageError.missingValue(argument)
                }
                connectIP = value
            case "--connect-port":
                guard let value = iterator.next(), let parsed = Int(value) else {
                    throw HelperUsageError.missingValue(argument)
                }
                connectPort = parsed
            case "--fake-sni":
                guard let value = iterator.next() else {
                    throw HelperUsageError.missingValue(argument)
                }
                fakeSNI = value
            case "--log-level":
                guard let value = iterator.next() else {
                    throw HelperUsageError.missingValue(argument)
                }
                logLevel = ProxyLogLevel.parse(value)
            case "--help", "-h":
                showHelp = true
            default:
                throw HelperUsageError.invalidArgument(argument)
            }
        }

        return HelperOptions(
            showHelp: showHelp,
            configPath: configPath,
            listenHost: listenHost,
            listenPort: listenPort,
            connectIP: connectIP,
            connectPort: connectPort,
            fakeSNI: fakeSNI,
            logLevel: logLevel
        )
    }

    func loadConfiguration() throws -> TunnelConfiguration {
        let base: TunnelConfiguration
        if let configPath {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            let listenHost: String = raw["LISTEN_HOST"] as? String ?? TunnelConfiguration.defaults.listenHost
            let listenPort: Int = (raw["LISTEN_PORT"] as? NSNumber)?.intValue ?? TunnelConfiguration.defaults.listenPort
            let connectIP: String = raw["CONNECT_IP"] as? String ?? TunnelConfiguration.defaults.connectIP
            let connectPort: Int = (raw["CONNECT_PORT"] as? NSNumber)?.intValue ?? TunnelConfiguration.defaults.connectPort
            let upstreamIP: String = raw["UPSTREAM_IP"] as? String ?? TunnelConfiguration.defaults.upstreamIP
            let upstreamPort: Int = (raw["UPSTREAM_PORT"] as? NSNumber)?.intValue ?? TunnelConfiguration.defaults.upstreamPort
            let fakeSNI: String = raw["FAKE_SNI"] as? String ?? TunnelConfiguration.defaults.fakeSNI
            let logLevel: ProxyLogLevel = ProxyLogLevel.parse(raw["LOG_LEVEL"] as? String)
            let dnsServers: [String] = []
            let excludedIPv4Addresses: [String] = []

            base = TunnelConfiguration(
                listenHost: listenHost,
                listenPort: listenPort,
                connectIP: connectIP,
                connectPort: connectPort,
                upstreamIP: upstreamIP,
                upstreamPort: upstreamPort,
                fakeSNI: fakeSNI,
                logLevel: logLevel,
                httpProxyPort: nil,
                socksProxyPort: nil,
                dnsServers: dnsServers,
                excludedIPv4Addresses: excludedIPv4Addresses
            )
        } else {
            base = .defaults
        }

        let finalListenHost: String = listenHost ?? base.listenHost
        let finalListenPort: Int = listenPort ?? base.listenPort
        let finalConnectIP: String = connectIP ?? base.connectIP
        let finalConnectPort: Int = connectPort ?? base.connectPort
        let finalFakeSNI: String = fakeSNI ?? base.fakeSNI
        let finalLogLevel: ProxyLogLevel = logLevel ?? base.logLevel
        let finalDNSServers: [String] = []
        let finalExcludedIPv4Addresses: [String] = base.excludedIPv4Addresses

        return TunnelConfiguration(
            listenHost: finalListenHost,
            listenPort: finalListenPort,
            connectIP: finalConnectIP,
            connectPort: finalConnectPort,
            upstreamIP: base.upstreamIP,
            upstreamPort: base.upstreamPort,
            fakeSNI: finalFakeSNI,
            logLevel: finalLogLevel,
            httpProxyPort: base.httpProxyPort,
            socksProxyPort: base.socksProxyPort,
            dnsServers: finalDNSServers,
            excludedIPv4Addresses: finalExcludedIPv4Addresses
        )
    }
}
