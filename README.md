# Proxy Toggle

A free, personal-use reimplementation of the *oneTapProxy / ProxySwitch* app:
one-tap HTTP/HTTPS proxy on/off, saved proxy profiles, a home-screen widget, and
a "Toggle Proxy" Shortcuts action. No RevenueCat paywall, no Firebase analytics —
just the proxy feature.

**Deployment target: iOS 16.0** (works on iPhone X / iOS 16.7.x). iOS 16 widgets
can't run code on tap, so the home-screen widget toggles by deep-linking into the
app (`proxytoggle://toggle`), which then flips the tunnel.

## How it works

iOS has no public API to change the system Wi-Fi proxy directly. Like the
original app, this uses a **Packet Tunnel (`NEPacketTunnelProvider`)** that does
*not* route your traffic — it just brings up a dummy tunnel so it can attach
system-wide **`NEProxySettings`**. While the toggle is on, HTTP/HTTPS traffic
honors your proxy; turning it off removes the proxy. The main app drives this via
`NETunnelProviderManager`.

```
ProxyToggle (app)  ──saves profile + start/stop──▶  NETunnelProviderManager
       │                                                     │
       │  App Group: group.com.personal.proxytoggle          ▼
       └────────────────────────────────┐         PacketTunnel.appex
                                         │         (applies NEProxySettings)
            ProxyWidget.appex  ◀─────────┘
        (home widget + Control Center toggle,
         toggles the same tunnel via App Intents)
```

## Targets

| Target         | Type              | Role                                            |
|----------------|-------------------|-------------------------------------------------|
| `ProxyToggle`  | app               | UI: toggle, profile list/editor, LAN scanner    |
| `PacketTunnel` | app-extension     | The `NEPacketTunnelProvider` that sets the proxy |
| `ProxyWidget`  | app-extension     | WidgetKit widget + iOS 18 Control Center toggle |

All three share the code in `Shared/` and the App Group container.

## Build & install (jailbroken / TrollStore)

You picked a **jailbroken device**, so we can grant the
`com.apple.developer.networking.networkextension` entitlement without a paid
Apple Developer account.

```bash
brew install xcodegen ldid     # one-time
./build.sh                     # generates project, builds, fake-signs, makes IPA
```

This produces `build/ProxyToggle.ipa`. Then either:

- **TrollStore (recommended):** open the `.ipa` in TrollStore. It re-signs while
  preserving the embedded entitlements, so the tunnel + widgets work.
- **Rootful jailbreak:** copy `build/.../ProxyToggle.app` to `/Applications` on
  the device, then run `uicache -p /Applications/ProxyToggle.app`.

> If you'd rather work in Xcode directly: run `xcodegen generate`, open
> `ProxyToggle.xcodeproj`, and build. With a real signing team you can run it on
> a normal (non-jailbroken) device too — the entitlements are already declared.

## First run

1. Launch the app, tap **+** to add a proxy (host + port; auth optional), or tap
   the **Wi-Fi** icon to scan the LAN for tools like Proxyman.
2. Select a profile (checkmark), then flip the big switch. iOS will ask once to
   allow the VPN/proxy configuration.
3. Add the **Proxy Toggle** widget to your home screen (tapping it opens the app
   and toggles), and/or use the **Toggle Proxy** Shortcuts action for Back Tap /
   automations.

## Customize

- Bundle ids / App Group live in `Shared/AppConstants.swift` **and** `project.yml`
  + the three `.entitlements` files — change them together.
- Only HTTP/HTTPS is supported (what `NEProxySettings` allows). SOCKS would need a
  full tun2socks implementation inside the tunnel.

## Notes

This is independent, clean-room code based on the *architecture* of the original
(observed: a packet-tunnel + App Group + widgets). It does not contain any of the
original's code or assets. For personal use.
