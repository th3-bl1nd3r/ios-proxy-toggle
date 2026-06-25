import Foundation

/// Central place for identifiers shared across the app and its extensions.
/// If you change the bundle id prefix, change it here AND in project.yml.
enum AppConstants {
    static let appGroup       = "group.com.personal.proxytoggle"
    static let mainBundleID   = "com.personal.proxytoggle"
    static let tunnelBundleID = "com.personal.proxytoggle.tunnel"
    static let widgetKind     = "ProxyToggleWidget"
    static let controlKind    = "com.personal.proxytoggle.control"
    static let urlScheme      = "proxytoggle"

    /// Bonjour service type used to discover proxy debugging tools on the LAN
    /// (Proxyman advertises `_Proxyman._tcp.`; Charles/others vary).
    static let bonjourProxyService = "_Proxyman._tcp."
}
