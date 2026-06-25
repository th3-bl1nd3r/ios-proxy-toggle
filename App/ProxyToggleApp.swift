import SwiftUI
import NetworkExtension

@main
struct ProxyToggleApp: App {
    @StateObject private var store = ProfileStore.shared
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(model)
                .onOpenURL { url in
                    // Deep link from the widget: proxytoggle://toggle
                    if url.host == "toggle" {
                        Task { await model.toggle() }
                    }
                }
        }
    }
}

/// Observes live VPN status for the UI and exposes toggle actions.
@MainActor
final class AppModel: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var lastError: String?

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() }
    }

    var isOn: Bool { status == .connected || status == .connecting || status == .reasserting }

    var statusText: String {
        switch status {
        case .connected:    return "Proxy On"
        case .connecting:   return "Connecting…"
        case .reasserting:  return "Reconnecting…"
        case .disconnecting: return "Disconnecting…"
        case .disconnected, .invalid: return "Proxy Off"
        @unknown default:   return "Unknown"
        }
    }

    func refresh() async {
        status = await TunnelManager.status()
        ProfileStore.shared.isProxyOn = isOn
    }

    func toggle() async {
        lastError = nil
        do { try await TunnelManager.toggle() }
        catch { lastError = error.localizedDescription }
        await refresh()
    }
}
