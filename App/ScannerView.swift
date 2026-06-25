import SwiftUI

struct ScannerView: View {
    @StateObject private var scanner = LANScanner()
    @Environment(\.dismiss) private var dismiss
    var onPick: (ProxyProfile) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if scanner.results.isEmpty {
                        HStack {
                            if scanner.isScanning { ProgressView() }
                            Text(scanner.isScanning ? "Searching local network…" : "Nothing found yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(scanner.results) { item in
                        Button {
                            onPick(ProxyProfile(name: item.name, host: item.host, port: item.port))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.body.weight(.medium))
                                Text("\(item.host):\(item.port)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Discovers proxy tools (e.g. Proxyman) advertising on your Wi-Fi. You can also add a proxy manually with +.")
                }
            }
            .navigationTitle("Scan Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { scanner.start() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .onAppear { scanner.start() }
            .onDisappear { scanner.stop() }
        }
    }
}
