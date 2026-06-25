#!/usr/bin/env bash
# Build, fake-sign with entitlements (ldid), and package an unsigned IPA.
# Designed for jailbroken / TrollStore installs.
#
# Requirements:  brew install xcodegen ldid
set -euo pipefail
cd "$(dirname "$0")"

DD="$PWD/build"
PRODUCTS="$DD/sym/Release-iphoneos"
APP="$PRODUCTS/ProxyToggle.app"

echo "==> Cleaning build dir"
rm -rf "$DD"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building (unsigned)"
# NOTE: we build with `-target`, NOT `-scheme`. On some Xcode installs scheme
# builds break in destination resolution ("Found no destinations" /
# "DVTBuildVersion" / "supported platforms empty") for the "Any iOS Device"
# placeholder. `-target` + `-sdk iphoneos` skips that resolution entirely and is
# deterministic. Building the app target also builds + embeds its extension
# dependencies. We use SYMROOT/OBJROOT because -derivedDataPath requires -scheme.
xcodebuild \
  -project ProxyToggle.xcodeproj \
  -target ProxyToggle \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$DD/sym" OBJROOT="$DD/obj" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

echo "==> Ad-hoc signing nested binaries, then applying entitlements"
# Sign embedded frameworks / swift dylibs first.
if [ -d "$APP/Frameworks" ]; then
  find "$APP/Frameworks" -type f -name "*.dylib" -exec ldid -S {} \;
  for fw in "$APP/Frameworks"/*.framework; do
    [ -d "$fw" ] && ldid -S "$fw/$(basename "$fw" .framework)" || true
  done
fi

# Apply real entitlements to the three things that need them.
ldid -SApp/ProxyToggle.entitlements "$APP/ProxyToggle"
ldid -STunnel/Tunnel.entitlements   "$APP/PlugIns/PacketTunnel.appex/PacketTunnel"
ldid -SWidget/Widget.entitlements   "$APP/PlugIns/ProxyWidget.appex/ProxyWidget"

echo "==> Packaging IPA"
rm -rf "$DD/Payload" "$DD/ProxyToggle.ipa"
mkdir -p "$DD/Payload"
cp -R "$APP" "$DD/Payload/"
( cd "$DD" && zip -qr ProxyToggle.ipa Payload )

echo "==> Done: $DD/ProxyToggle.ipa"
echo "    Install via TrollStore (keeps the embedded entitlements),"
echo "    or copy the .app to /Applications on a jailbroken device and run: uicache -p /Applications/ProxyToggle.app"
