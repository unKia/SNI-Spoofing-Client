import Foundation

enum ProxyLinkProtocol: String {
    case vless
    case vmess
    case trojan
    case shadowsocks
}

struct VlessConfig {
    let protocolKind: ProxyLinkProtocol
    let originalAddress: String
    let originalPort: Int
    let uuid: String?
    let password: String?
    let method: String?
    let vmessSecurity: String
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
        var outbound: [String: Any]

        switch protocolKind {
        case .vless:
            guard let uuid, !uuid.isEmpty else {
                throw NSError(
                    domain: "VlessParser",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "VLESS config is missing UUID."]
                )
            }

            var user: [String: Any] = [
                "id": uuid,
                "encryption": encryption,
            ]
            if let flow, !flow.isEmpty {
                user["flow"] = flow
            }

            outbound = [
                "protocol": "vless",
                "settings": [
                    "vnext": [[
                        "address": outboundAddress,
                        "port": outboundPort,
                        "users": [user],
                    ]]
                ],
            ]

        case .vmess:
            guard let uuid, !uuid.isEmpty else {
                throw NSError(
                    domain: "VlessParser",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "VMess config is missing id."]
                )
            }

            var user: [String: Any] = [
                "id": uuid,
                "security": vmessSecurity,
            ]
            if let flow, !flow.isEmpty {
                user["flow"] = flow
            }

            outbound = [
                "protocol": "vmess",
                "settings": [
                    "vnext": [[
                        "address": outboundAddress,
                        "port": outboundPort,
                        "users": [user],
                    ]]
                ],
            ]

        case .trojan:
            guard let password, !password.isEmpty else {
                throw NSError(
                    domain: "VlessParser",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Trojan config is missing password."]
                )
            }

            outbound = [
                "protocol": "trojan",
                "settings": [
                    "servers": [[
                        "address": outboundAddress,
                        "port": outboundPort,
                        "password": password,
                    ]],
                ],
            ]

        case .shadowsocks:
            guard let method, !method.isEmpty else {
                throw NSError(
                    domain: "VlessParser",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Shadowsocks config is missing method."]
                )
            }
            guard let password, !password.isEmpty else {
                throw NSError(
                    domain: "VlessParser",
                    code: 8,
                    userInfo: [NSLocalizedDescriptionKey: "Shadowsocks config is missing password."]
                )
            }

            outbound = [
                "protocol": "shadowsocks",
                "settings": [
                    "address": outboundAddress,
                    "port": outboundPort,
                    "method": method,
                    "password": password,
                ],
            ]
        }

        if protocolKind != .shadowsocks, let streamSettings = Self.buildStreamSettings(
            network: network,
            security: security,
            sni: sni,
            allowInsecure: allowInsecure,
            host: host,
            path: path,
            fingerprint: fingerprint,
            alpn: alpn,
            publicKey: publicKey,
            shortID: shortID,
            spiderX: spiderX,
            serviceName: serviceName,
            authority: authority,
            headerType: headerType,
            mode: mode
        ) {
            outbound["streamSettings"] = streamSettings
        }

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

    private static func buildStreamSettings(
        network: String,
        security: String,
        sni: String,
        allowInsecure: Bool,
        host: String,
        path: String,
        fingerprint: String?,
        alpn: [String],
        publicKey: String?,
        shortID: String?,
        spiderX: String?,
        serviceName: String?,
        authority: String?,
        headerType: String?,
        mode: String?
    ) -> [String: Any]? {
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

        return streamSettings
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
            return "Config format is invalid."
        case .missingCoreFields:
            return "Config is missing core connection fields."
        case let .unsupportedScheme(scheme):
            return "Unsupported config scheme: \(scheme)"
        }
    }
}

enum VlessParser {
    static func parse(uri: String) throws -> VlessConfig {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VlessParserError.invalidFormat
        }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("vless://") {
            return try parseStandardLink(uri: trimmed, scheme: .vless, defaultSecurity: "none", defaultRemark: "VLESS")
        }
        if lowercased.hasPrefix("trojan://") {
            return try parseStandardLink(uri: trimmed, scheme: .trojan, defaultSecurity: "tls", defaultRemark: "Trojan")
        }
        if lowercased.hasPrefix("vmess://") {
            return try parseVmess(uri: trimmed)
        }
        if lowercased.hasPrefix("ss://") {
            return try parseShadowsocks(uri: trimmed)
        }

        throw VlessParserError.unsupportedScheme(URL(string: trimmed)?.scheme ?? "unknown")
    }

    private static func parseStandardLink(
        uri: String,
        scheme: ProxyLinkProtocol,
        defaultSecurity: String,
        defaultRemark: String
    ) throws -> VlessConfig {
        guard let url = URL(string: uri) else {
            throw VlessParserError.invalidFormat
        }
        guard url.scheme?.lowercased() == scheme.rawValue else {
            throw VlessParserError.unsupportedScheme(url.scheme ?? "unknown")
        }
        guard let host = url.host, let port = url.port else {
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

        let uuid = url.user?.removingPercentEncoding
        let password = [url.user?.removingPercentEncoding, url.password?.removingPercentEncoding]
            .compactMap { $0 }
            .joined(separator: url.password == nil ? "" : ":")
        let network = nonEmpty(["type", "net"], default: "tcp")
        let streamSecurity = normalizeSecurity(nonEmpty(["security", "tls"], default: defaultSecurity), defaultValue: defaultSecurity)
        let sni = nonEmpty(["sni", "serverName", "peer"], default: host)
        let hostHeader = nonEmpty(["host"], default: host)
        let path = nonEmpty(["path"], default: "/")
        let allowInsecure = nonEmpty(["allowInsecure", "insecure"], default: "0") == "1"
        let remark = url.fragment?.removingPercentEncoding ?? defaultRemark
        let flow = value("flow")
        let fingerprint = nonEmpty(["fp", "fingerprint"])
        let alpn = nonEmpty(["alpn"])
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let publicKey = value("pbk")
        let shortID = value("sid")
        let spiderX = value("spx")
        let serviceName = nonEmpty(
            ["serviceName"],
            default: network == "grpc" ? path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : ""
        )
        let authority = value("authority")
        let headerType = value("headerType")
        let mode = value("mode")
        let encryption = nonEmpty(["encryption"], default: "none")

        return VlessConfig(
            protocolKind: scheme,
            originalAddress: host,
            originalPort: port,
            uuid: scheme == .shadowsocks ? nil : uuid,
            password: scheme == .trojan ? (password.isEmpty ? nil : password) : nil,
            method: nil,
            vmessSecurity: "auto",
            remark: remark,
            network: network,
            security: streamSecurity,
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

    private static func parseVmess(uri: String) throws -> VlessConfig {
        guard let payload = stripScheme(uri, scheme: "vmess") else {
            throw VlessParserError.invalidFormat
        }

        let parts = payload.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let encoded = String(parts[0])
        let jsonCandidate = decodeBase64URLString(encoded) ?? encoded.removingPercentEncoding ?? encoded

        guard let data = jsonCandidate.data(using: .utf8) else {
            throw VlessParserError.invalidFormat
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let raw = object as? [String: Any] else {
            throw VlessParserError.invalidFormat
        }

        func stringValue(_ keys: [String], default fallback: String = "") -> String {
            for key in keys {
                if let value = raw[key] as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let number = raw[key] as? NSNumber {
                    return number.stringValue
                }
            }
            return fallback
        }

        let remark = parts.count > 1
            ? String(parts[1]).removingPercentEncoding ?? "VMess"
            : stringValue(["ps"], default: "VMess")

        func intValue(_ keys: [String]) -> Int? {
            for key in keys {
                if let value = raw[key] as? Int {
                    return value
                }
                if let value = raw[key] as? NSNumber {
                    return value.intValue
                }
                if let string = raw[key] as? String, let parsed = Int(string) {
                    return parsed
                }
            }
            return nil
        }

        let host = stringValue(["add", "address"])
        let port = intValue(["port"])
        guard !host.isEmpty, let port else {
            throw VlessParserError.missingCoreFields
        }

        let network = stringValue(["net", "type"], default: "tcp")
        let userSecurity = stringValue(["scy", "security"], default: "auto")
        let streamSecurity = normalizeSecurity(stringValue(["tls"], default: ""), defaultValue: "none")
        let sni = stringValue(["sni", "serverName", "peer"], default: host)
        let hostHeader = stringValue(["host"], default: host)
        let path = stringValue(["path"], default: "/")
        let allowInsecure = stringValue(["allowInsecure", "insecure"], default: "0") == "1"
        let flow = stringValue(["flow"], default: "")
        let fingerprint = stringValue(["fp", "fingerprint"], default: "")
        let alpn = stringValue(["alpn"], default: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let publicKey = stringValue(["pbk"], default: "")
        let shortID = stringValue(["sid"], default: "")
        let spiderX = stringValue(["spx"], default: "")
        let serviceName = stringValue(["serviceName"], default: "")
        let authority = stringValue(["authority"], default: "")
        let headerType = stringValue(["headerType"], default: "")
        let mode = stringValue(["mode"], default: "")

        return VlessConfig(
            protocolKind: .vmess,
            originalAddress: host,
            originalPort: port,
            uuid: stringValue(["id"], default: ""),
            password: nil,
            method: nil,
            vmessSecurity: userSecurity,
            remark: remark,
            network: network,
            security: streamSecurity,
            sni: sni,
            host: hostHeader,
            path: path,
            allowInsecure: allowInsecure,
            flow: flow.isEmpty ? nil : flow,
            fingerprint: fingerprint.isEmpty ? nil : fingerprint,
            alpn: alpn,
            publicKey: publicKey.isEmpty ? nil : publicKey,
            shortID: shortID.isEmpty ? nil : shortID,
            spiderX: spiderX.isEmpty ? nil : spiderX,
            serviceName: serviceName.isEmpty ? nil : serviceName,
            authority: authority.isEmpty ? nil : authority,
            headerType: headerType.isEmpty ? nil : headerType,
            mode: mode.isEmpty ? nil : mode,
            encryption: "none"
        )
    }

    private static func parseShadowsocks(uri: String) throws -> VlessConfig {
        guard let payload = stripScheme(uri, scheme: "ss") else {
            throw VlessParserError.invalidFormat
        }

        let parts = payload.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let base = String(parts[0])
        let baseRemark = parts.count > 1 ? String(parts[1]).removingPercentEncoding ?? "Shadowsocks" : "Shadowsocks"
        let querySplit = base.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let authorityOrEncoded = String(querySplit[0])
        let querySuffix = querySplit.count > 1 ? "?\(querySplit[1])" : ""
        let decodedAuthority = decodeBase64URLString(authorityOrEncoded) ?? authorityOrEncoded
        let components = URLComponents(string: "ss://\(decodedAuthority)\(querySuffix)")

        guard let components, let host = components.host, let port = components.port else {
            throw VlessParserError.missingCoreFields
        }

        let method = components.user?.removingPercentEncoding
        let password = [components.user?.removingPercentEncoding, components.password?.removingPercentEncoding]
            .compactMap { $0 }
            .joined(separator: components.password == nil ? "" : ":")

        let queryItems = components.queryItems ?? []
        func value(_ key: String) -> String? {
            queryItems.first(where: { $0.name == key })?.value?.removingPercentEncoding
        }

        let allowInsecure = value("allowInsecure").map { $0 == "1" } ?? false
        let remark = value("remarks") ?? value("name") ?? value("ps") ?? baseRemark

        return VlessConfig(
            protocolKind: .shadowsocks,
            originalAddress: host,
            originalPort: port,
            uuid: nil,
            password: password.isEmpty ? nil : password,
            method: method,
            vmessSecurity: "auto",
            remark: remark,
            network: value("type") ?? value("net") ?? "tcp",
            security: "none",
            sni: value("sni") ?? host,
            host: value("host") ?? host,
            path: value("path") ?? "/",
            allowInsecure: allowInsecure,
            flow: value("flow"),
            fingerprint: value("fp"),
            alpn: (value("alpn") ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            publicKey: value("pbk"),
            shortID: value("sid"),
            spiderX: value("spx"),
            serviceName: value("serviceName"),
            authority: value("authority"),
            headerType: value("headerType"),
            mode: value("mode"),
            encryption: "none"
        )
    }

    private static func stripScheme(_ uri: String, scheme: String) -> String? {
        let prefix = "\(scheme)://"
        guard uri.lowercased().hasPrefix(prefix) else {
            return nil
        }
        return String(uri.dropFirst(prefix.count))
    }

    private static func decodeBase64URLString(_ input: String) -> String? {
        var normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        normalized = normalized.replacingOccurrences(of: "-", with: "+")
        normalized = normalized.replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: normalized, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func normalizeSecurity(_ raw: String, defaultValue: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return defaultValue
        }
        switch value.lowercased() {
        case "1", "true", "tls":
            return "tls"
        case "reality":
            return "reality"
        case "0", "false", "none":
            return "none"
        default:
            return value
        }
    }
}
