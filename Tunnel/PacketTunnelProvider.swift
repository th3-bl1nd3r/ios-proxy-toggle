import NetworkExtension

/// A "proxy-only" packet tunnel. It does NOT route real traffic through itself —
/// it brings up a dummy tunnel purely so it can attach system-wide
/// `NEProxySettings`. While the tunnel is active iOS routes HTTP/HTTPS through
/// the configured proxy; when it stops, the proxy is removed. This is the same
/// trick the original ProxySwitch app uses.
class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        let config = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration ?? [:]

        let host = config["host"] as? String ?? ""
        let port = config["port"] as? Int ?? 0
        guard !host.isEmpty, port > 0 else {
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        // Dummy private address so the tunnel interface is valid. With no
        // included routes, the system sends us no packets — apps keep their
        // normal route, they just honor the proxy settings below.
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = []
        ipv4.excludedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // The actual proxy configuration.
        let server = NEProxyServer(address: host, port: port)
        if (config["requiresAuth"] as? Bool) == true,
           let user = config["username"] as? String, !user.isEmpty {
            server.authenticationRequired = true
            server.username = user
            server.password = config["password"] as? String
        }

        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpServer = server
        proxy.httpsEnabled = true
        proxy.httpsServer = server
        proxy.excludeSimpleHostnames = false
        proxy.matchDomains = [""]   // empty string == match every domain
        settings.proxySettings = proxy

        setTunnelNetworkSettings(settings) { error in
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        setTunnelNetworkSettings(nil) { _ in
            completionHandler()
        }
    }
}
