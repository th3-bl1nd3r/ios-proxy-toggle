import Foundation
import Network

/// Discovers proxy/debugging tools advertised on the local network over Bonjour
/// (e.g. Proxyman). Mirrors the original app's NetworkScanner feature.
@MainActor
final class LANScanner: ObservableObject {
    struct Discovered: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let host: String
        let port: Int
    }

    @Published var results: [Discovered] = []
    @Published var isScanning = false

    private var browser: NWBrowser?
    private var connections: [NWConnection] = []

    func start() {
        stop()
        results = []
        isScanning = true

        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(
            type: AppConstants.bonjourProxyService, domain: nil
        )
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                for result in results { self?.resolve(result) }
            }
        }
        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel(); browser = nil
        connections.forEach { $0.cancel() }; connections = []
        isScanning = false
    }

    private func resolve(_ result: NWBrowser.Result) {
        let conn = NWConnection(to: result.endpoint, using: .tcp)
        connections.append(conn)
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            if case .ready = state, let path = conn.currentPath,
               case let .hostPort(host, port) = path.remoteEndpoint {
                let name: String = {
                    if case let .service(svcName, _, _, _) = result.endpoint { return svcName }
                    return "\(host)"
                }()
                let entry = Discovered(name: name,
                                       host: "\(host)".components(separatedBy: "%").first ?? "\(host)",
                                       port: Int(port.rawValue))
                Task { @MainActor in
                    if !self.results.contains(where: { $0.host == entry.host && $0.port == entry.port }) {
                        self.results.append(entry)
                    }
                }
                conn.cancel()
            }
        }
        conn.start(queue: .main)
    }
}
