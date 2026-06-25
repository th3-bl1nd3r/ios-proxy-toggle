import Foundation
import Combine

/// Persists proxy profiles + selection in the shared App Group container so the
/// app, the tunnel extension, and the widgets all see the same data.
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    private let defaults: UserDefaults
    private enum Keys {
        static let profiles   = "profiles"
        static let selectedID = "selectedProfileID"
        static let proxyOn    = "isProxyOn"
    }

    @Published private(set) var profiles: [ProxyProfile] = []

    private init() {
        // Falls back to .standard if the App Group isn't configured yet so the
        // app still launches during early setup.
        defaults = UserDefaults(suiteName: AppConstants.appGroup) ?? .standard
        load()
    }

    // MARK: - Loading / saving

    private func load() {
        if let data = defaults.data(forKey: Keys.profiles),
           let decoded = try? JSONDecoder().decode([ProxyProfile].self, from: data) {
            profiles = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Keys.profiles)
        }
    }

    // MARK: - Mutations

    func upsert(_ profile: ProxyProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        if selectedProfileID == nil { selectedProfileID = profile.id }
        persist()
    }

    func delete(_ profile: ProxyProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        let removed = offsets.map { profiles[$0] }
        profiles.remove(atOffsets: offsets)
        if let sel = selectedProfileID, removed.contains(where: { $0.id == sel }) {
            selectedProfileID = profiles.first?.id
        }
        persist()
    }

    // MARK: - Selection / state

    var selectedProfileID: UUID? {
        get {
            guard let s = defaults.string(forKey: Keys.selectedID) else { return nil }
            return UUID(uuidString: s)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Keys.selectedID)
            objectWillChange.send()
        }
    }

    var selectedProfile: ProxyProfile? {
        guard let id = selectedProfileID else { return profiles.first }
        return profiles.first { $0.id == id } ?? profiles.first
    }

    /// Cached "is the proxy on" flag, written by the app/intents whenever the
    /// tunnel is toggled. Widgets read this for a fast glance without having to
    /// load the VPN manager.
    var isProxyOn: Bool {
        get { defaults.bool(forKey: Keys.proxyOn) }
        set {
            defaults.set(newValue, forKey: Keys.proxyOn)
            objectWillChange.send()
        }
    }
}
