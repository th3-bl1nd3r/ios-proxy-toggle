import WidgetKit
import SwiftUI

struct ProxyEntry: TimelineEntry {
    let date: Date
    let isOn: Bool
    let profileName: String
}

struct ProxyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProxyEntry {
        ProxyEntry(date: Date(), isOn: false, profileName: "Proxy")
    }

    func getSnapshot(in context: Context, completion: @escaping (ProxyEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProxyEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> ProxyEntry {
        let store = ProfileStore.shared
        return ProxyEntry(
            date: Date(),
            isOn: store.isProxyOn,
            profileName: store.selectedProfile?.name.isEmpty == false
                ? store.selectedProfile!.name
                : (store.selectedProfile?.subtitle ?? "No profile")
        )
    }
}

struct ProxyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: ProxyProvider()) { entry in
            ProxyWidgetView(entry: entry)
                .widgetBackgroundCompat()
        }
        .configurationDisplayName("Proxy Toggle")
        .description("Tap to turn your proxy on or off.")
        .supportedFamilies([.systemSmall])
    }
}

struct ProxyWidgetView: View {
    let entry: ProxyEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.isOn ? "shield.lefthalf.filled" : "shield.slash")
                .font(.system(size: 34))
                .foregroundColor(entry.isOn ? .green : .secondary)

            Text(entry.isOn ? "Proxy On" : "Proxy Off")
                .font(.headline)

            Text(entry.profileName)
                .font(.caption2).foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // On iOS 16 widgets can't run code on tap — tapping opens the app via
        // this URL, and the app performs the toggle (see onOpenURL in the app).
        .widgetURL(URL(string: "\(AppConstants.urlScheme)://toggle"))
    }
}

private extension View {
    /// iOS 17 requires `containerBackground`; iOS 16 must not call it.
    @ViewBuilder func widgetBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}
