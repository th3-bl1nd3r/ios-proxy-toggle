import Foundation

/// A single saved proxy configuration. HTTP/HTTPS only (matches the original app
/// and what NEProxySettings supports natively — no SOCKS).
struct ProxyProfile: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var requiresAuth: Bool
    var username: String
    var password: String

    init(id: UUID = UUID(),
         name: String = "",
         host: String = "",
         port: Int = 8888,
         requiresAuth: Bool = false,
         username: String = "",
         password: String = "") {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.requiresAuth = requiresAuth
        self.username = username
        self.password = password
    }

    var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && (1...65535).contains(port)
    }

    var subtitle: String { "\(host):\(port)" }

    /// Plist-serializable dictionary handed to the tunnel via
    /// `NETunnelProviderProtocol.providerConfiguration`. Must contain only
    /// property-list types (String / Int / Bool).
    var providerConfiguration: [String: Any] {
        [
            "host": host,
            "port": port,
            "requiresAuth": requiresAuth,
            "username": username,
            "password": password,
        ]
    }
}
