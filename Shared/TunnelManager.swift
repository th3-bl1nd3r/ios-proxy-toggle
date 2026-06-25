import Foundation
import NetworkExtension
import WidgetKit

enum ProxyError: LocalizedError {
    case noProfile
    var errorDescription: String? {
        switch self {
        case .noProfile: return "No proxy profile selected."
        }
    }
}

/// Wraps `NETunnelProviderManager` — installs the VPN/proxy profile and
/// starts/stops it. Shared by the app and the widget's intents.
enum TunnelManager {

    /// The single manager we own, or a fresh one if none exists yet.
    static func currentManager() async throws -> NETunnelProviderManager {
        let all = try await NETunnelProviderManager.loadAllFromPreferences()
        return all.first ?? NETunnelProviderManager()
    }

    static func status() async -> NEVPNStatus {
        (try? await currentManager())?.connection.status ?? .invalid
    }

    /// Writes the selected profile into the saved VPN configuration.
    private static func save(profile: ProxyProfile) async throws {
        let manager = try await currentManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConstants.tunnelBundleID
        proto.serverAddress = profile.subtitle
        proto.providerConfiguration = profile.providerConfiguration

        manager.protocolConfiguration = proto
        manager.localizedDescription = "Proxy Toggle — \(profile.name.isEmpty ? profile.subtitle : profile.name)"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        // A reload after save is required before the connection can be started.
        try await manager.loadFromPreferences()
    }

    static func start() async throws {
        guard let profile = ProfileStore.shared.selectedProfile else { throw ProxyError.noProfile }
        try await save(profile: profile)
        let manager = try await currentManager()
        try manager.connection.startVPNTunnel()
        ProfileStore.shared.isProxyOn = true
        reloadWidgets()
    }

    static func stop() async throws {
        let manager = try await currentManager()
        manager.connection.stopVPNTunnel()
        ProfileStore.shared.isProxyOn = false
        reloadWidgets()
    }

    static func toggle() async throws {
        let status = await status()
        if status == .connected || status == .connecting || status == .reasserting {
            try await stop()
        } else {
            try await start()
        }
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
