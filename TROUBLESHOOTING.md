# Troubleshooting

Problems hit while getting this project to build + install, and how each was
solved. Most are specific to building an XcodeGen project from the command line
on this machine (Xcode 26.2, jailbroken iPhone X on iOS 16.7.x, TrollStore).

---

## 1. `xcodebuild: error: Found no destinations for the scheme`

Also shows as `IDERunDestination: Supported platforms for the buildables in the
current scheme is empty`, and sometimes a misleading
`iOS 26.2 is not installed` (the SDK *is* installed).

**Cause:** XcodeGen didn't emit `SUPPORTED_PLATFORMS` into the project. Xcode
resolves the build *destination* before applying command-line build settings, so
with that key missing it can't pick the "Any iOS Device" placeholder.

**Fix:** These are baked into `project.yml` under `settings.base`:

```yaml
SDKROOT: iphoneos
SUPPORTED_PLATFORMS: iphoneos
SUPPORTS_MACCATALYST: "NO"
```

---

## 2. `AppIntentsSSUTraining ... error: Unable to parse Info.plist`

**Cause:** `GENERATE_INFOPLIST_FILE: NO` meant Xcode never injected the standard
`CFBundleIdentifier` / `CFBundleExecutable` keys, so the App Intents (Siri)
metadata step choked on the incomplete plist.

**Fix:** `project.yml` uses `GENERATE_INFOPLIST_FILE: "YES"` for every target.
Xcode synthesizes the standard bundle keys *and* merges the custom keys from each
target's `Info.plist` (NSExtension, NSBonjourServices, CFBundleURLTypes).

---

## 3. `call to main actor-isolated instance method in a synchronous nonisolated context`

**Cause:** Swift 6 actor isolation. A `Network`/Bonjour callback
(`browseResultsChangedHandler`) is nonisolated but called a `@MainActor` method.

**Fix:** Wrap the call: `Task { @MainActor in ... }` (see `App/LANScanner.swift`).

---

## 4. Random destination failures + `DVTDeviceOperation: Encountered a build number "" that is incompatible with DVTBuildVersion`

This is the important, non-obvious one.

**Cause:** This Xcode 26.2 install's **run-destination resolver is broken** for the
device placeholder. Any `-scheme` build gambles on it — it fails
non-deterministically (sometimes all retries fail).

**Fix:** **Don't build with `-scheme`.** `build.sh` builds with `-target`, which
skips run-destination resolution entirely and is deterministic:

```sh
xcodebuild -project ProxyToggle.xcodeproj -target ProxyToggle \
  -configuration Release -sdk iphoneos \
  SYMROOT="$PWD/build/sym" OBJROOT="$PWD/build/obj" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

`SYMROOT`/`OBJROOT` are used instead of `-derivedDataPath` because the latter
requires `-scheme`. Building the app target also builds + embeds its extension
dependencies.

> **If you open the project in the Xcode GUI**, the "Any iOS Device" selector may
> misbehave the same way. The real cure is fixing the install:
> `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, and if that
> doesn't help, reinstall Xcode.

---

## 5. `disk I/O error accessing build database` / `unable to rename temporary ... .pcm`

**Cause:** Leftover state in `build/` from earlier `-derivedDataPath` runs mixing
with the `SYMROOT` layout.

**Fix:** `build.sh` wipes the whole `build/` directory at the start of every run.

---

## 6. App won't install / launch on iPhone X — wrong iOS version

**Cause:** The project was first targeted at iOS 17, but iPhone X maxes out at
**iOS 16.7.x**, and it used iOS 17/18-only APIs.

**Fix:** Deployment target is **iOS 16.0** (`project.yml` → `deploymentTarget.iOS`).
iOS 17/18 APIs were replaced with iOS 16 equivalents:

| iOS 17/18 API                     | iOS 16 replacement                                  |
|-----------------------------------|-----------------------------------------------------|
| Interactive widget `Button(intent:)` | Widget deep-links `proxytoggle://toggle`; app toggles on open |
| `containerBackground(...)`        | Gated behind `if #available(iOS 17)`                |
| Control Center `ControlWidget` (18) | Removed                                            |
| `SetValueIntent` (18)             | Removed; kept `ToggleProxyIntent` Shortcuts action  |
| Two-param `.onChange(of:) { _, new in }` | Single-param `.onChange(of:) { new in }`     |
| `.topBarLeading` / `.topBarTrailing` | `.navigationBarLeading` / `.navigationBarTrailing` |

To confirm the built target version:

```sh
plutil -p build/sym/Release-iphoneos/ProxyToggle.app/Info.plist | grep MinimumOSVersion
# => "MinimumOSVersion" => "16.0"
```

---

## Entitlement / signing sanity checks

After `./build.sh`, verify the three binaries carry the right entitlements
(needed for the tunnel + App Group to work):

```sh
APP=build/sym/Release-iphoneos/ProxyToggle.app
for b in "$APP/ProxyToggle" \
         "$APP/PlugIns/PacketTunnel.appex/PacketTunnel" \
         "$APP/PlugIns/ProxyWidget.appex/ProxyWidget"; do
  echo "== $b =="
  ldid -e "$b" | grep -E "packet-tunnel-provider|application-groups|group\."
done
```

Each should list `packet-tunnel-provider` and `group.com.personal.proxytoggle`.
Install `build/ProxyToggle.ipa` with **TrollStore** (it preserves these embedded
entitlements).

---

## If the proxy toggles on but traffic doesn't route

The proxy-only tunnel lives in `Tunnel/PacketTunnelProvider.swift`. The spot most
likely to need tweaking per iOS version is the network-settings block:
`ipv4.includedRoutes = []` (capture nothing) + `proxy.matchDomains = [""]` (apply
to all). Add `os_log` there and watch in Console.app while toggling to debug.
