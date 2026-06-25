import AppIntents

/// A "Toggle Proxy" action exposed to Shortcuts / Siri (works on iOS 16+).
/// Handy for Back Tap, automations, or a Control Center shortcut. The
/// home-screen widget itself toggles via a deep link (iOS 16 widgets can't run
/// code on tap).
struct ToggleProxyIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Proxy"
    static var description = IntentDescription("Turns the HTTP proxy on or off.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        try await TunnelManager.toggle()
        return .result()
    }
}
