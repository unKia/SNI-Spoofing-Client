import Foundation

struct VlessConfig {
    let originalAddress: String
    let originalPort: Int
    let uuid: String
    let remark: String
    let network: String
    let security: String
    let sni: String
    let host: String
    let path: String
    let allowInsecure: Bool
    let flow: String?
    let fingerprint: String?
    let alpn: [String]
    let publicKey: String?
    let shortID: String?
    let spiderX: String?
    let serviceName: String?
    let authority: String?
    let headerType: String?
    let mode: String?
    let encryption: String

    func generateXrayConfig(
        inboundSocksPort: Int,
        inboundHttpPort: Int,
        outboundAddress: String,
        outboundPort: Int,
        logLevel: ProxyLogLevel = .info
    ) throws -> String {
        var user: [String: Any] = [
            "id": uuid,
            "encryption": encryption,
        ]
        if let flow, !flow.isEmpty {
            user["flow"] = flow
        }

        var outbound: [String: Any] = [
            "protocol": "vless",
            "settings": [
                "vnext": [[
                    "address": outboundAddress,
                    "port": outboundPort,
                    "users": [user],
                ]]
            ],
        ]

        var streamSettings: [String: Any] = [
            "network": network,
            "security": security,
        ]

        if security == "tls" {
            var tlsSettings: [String: Any] = [
                "serverName": sni,
                "allowInsecure": allowInsecure,
            ]
            if !alpn.isEmpty {
                tlsSettings["alpn"] = alpn
            }
            if let fingerprint, !fingerprint.isEmpty {
                tlsSettings["fingerprint"] = fingerprint
            }
            streamSettings["tlsSettings"] = tlsSettings
        } else if security == "reality" {
            var realitySettings: [String: Any] = [
                "serverName": sni,
                "allowInsecure": allowInsecure,
            ]
            if let fingerprint, !fingerprint.isEmpty {
                realitySettings["fingerprint"] = fingerprint
            }
            if let publicKey, !publicKey.isEmpty {
                realitySettings["publicKey"] = publicKey
            }
            if let shortID, !shortID.isEmpty {
                realitySettings["shortId"] = shortID
            }
            if let spiderX, !spiderX.isEmpty {
                realitySettings["spiderX"] = spiderX
            }
            streamSettings["realitySettings"] = realitySettings
        }

        switch network {
        case "ws":
            var headers: [String: Any] = [:]
            if !host.isEmpty {
                headers["Host"] = host
            }
            streamSettings["wsSettings"] = [
                "path": path,
                "headers": headers,
            ]
        case "grpc":
            var grpcSettings: [String: Any] = [:]
            if let serviceName, !serviceName.isEmpty {
                grpcSettings["serviceName"] = serviceName
            }
            if let authority, !authority.isEmpty {
                grpcSettings["authority"] = authority
            }
            if let mode, !mode.isEmpty {
                grpcSettings["multiMode"] = (mode == "multi")
            }
            streamSettings["grpcSettings"] = grpcSettings
        case "tcp":
            if let headerType, headerType == "http" {
                var requestHeaders: [String: Any] = [:]
                if !host.isEmpty {
                    requestHeaders["Host"] = [host]
                }
                streamSettings["tcpSettings"] = [
                    "header": [
                        "type": "http",
                        "request": [
                            "path": [path],
                            "headers": requestHeaders,
                        ]
                    ]
                ]
            }
        case "httpupgrade":
            var upgradeSettings: [String: Any] = [
                "path": path,
            ]
            if !host.isEmpty {
                upgradeSettings["host"] = host
            }
            streamSettings["httpupgradeSettings"] = upgradeSettings
        case "xhttp", "splithttp":
            var xhttpSettings: [String: Any] = [
                "path": path,
            ]
            if !host.isEmpty {
                xhttpSettings["host"] = host
            }
            if let mode, !mode.isEmpty {
                xhttpSettings["mode"] = mode
            }
            streamSettings["xhttpSettings"] = xhttpSettings
        default:
            break
        }

        outbound["streamSettings"] = streamSettings

        let root: [String: Any] = [
            "log": ["loglevel": Self.xrayLogLevel(from: logLevel)],
            "inbounds": [
                [
                    "tag": "socks-in",
                    "port": inboundSocksPort,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": true,
                    ],
                ],
                [
                    "tag": "http-in",
                    "port": inboundHttpPort,
                    "listen": "127.0.0.1",
                    "protocol": "http",
                    "settings": [
                        "allowTransparent": false,
                    ],
                ],
            ],
            "outbounds": [outbound],
        ]

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "VlessParser",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode Xray configuration."]
            )
        }
        return json
    }

    private static func xrayLogLevel(from level: ProxyLogLevel) -> String {
        switch level {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .error:
            return "warning"
        }
    }
}

enum VlessParserError: LocalizedError {
    case invalidFormat
    case missingCoreFields
    case unsupportedScheme(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "VLESS config format is invalid."
        case .missingCoreFields:
            return "VLESS config is missing UUID, host, or port."
        case let .unsupportedScheme(scheme):
            return "Unsupported config scheme: \(scheme)"
        }
    }
}

enum VlessParser {
    static func parse(uri: String) throws -> VlessConfig {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            throw VlessParserError.invalidFormat
        }
        guard url.scheme?.lowercased() == "vless" else {
            throw VlessParserError.unsupportedScheme(url.scheme ?? "unknown")
        }
        guard let uuid = url.user, let host = url.host, let port = url.port else {
            throw VlessParserError.missingCoreFields
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        func value(_ key: String) -> String? {
            queryItems.first(where: { $0.name == key })?.value?.removingPercentEncoding
        }

        func nonEmpty(_ keys: [String], default fallback: String = "") -> String {
            for key in keys {
                if let candidate = value(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty {
                    return candidate
                }
            }
            return fallback
        }

        let network = nonEmpty(["type"], default: "tcp")
        let security = nonEmpty(["security"], default: "none")
        let sni = nonEmpty(["sni", "serverName"], default: host)
        let hostHeader = nonEmpty(["host"], default: host)
        let path = nonEmpty(["path"], default: "/")
        let allowInsecure = nonEmpty(["allowInsecure"], default: "0") == "1"
        let remark = url.fragment?.removingPercentEncoding ?? "VLESS"
        let flow = value("flow")
        let fingerprint = nonEmpty(["fp", "fingerprint"])
        let alpn = nonEmpty(["alpn"])
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let publicKey = value("pbk")
        let shortID = value("sid")
        let spiderX = value("spx")
        let serviceName = nonEmpty(["serviceName"], default: network == "grpc" ? path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : "")
        let authority = value("authority")
        let headerType = value("headerType")
        let mode = value("mode")
        let encryption = nonEmpty(["encryption"], default: "none")

        return VlessConfig(
            originalAddress: host,
            originalPort: port,
            uuid: uuid,
            remark: remark,
            network: network,
            security: security,
            sni: sni,
            host: hostHeader,
            path: path,
            allowInsecure: allowInsecure,
            flow: flow,
            fingerprint: fingerprint.isEmpty ? nil : fingerprint,
            alpn: alpn,
            publicKey: publicKey,
            shortID: shortID,
            spiderX: spiderX,
            serviceName: serviceName.isEmpty ? nil : serviceName,
            authority: authority,
            headerType: headerType,
            mode: mode,
            encryption: encryption
        )
    }
}
