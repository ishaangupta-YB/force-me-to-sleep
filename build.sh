#!/usr/bin/env bash
#
# Builds NightShepherd.app from this SwiftPM package using only the
# Command Line Tools (no Xcode required).
#
set -euo pipefail

cd "$(dirname "$0")"

APP="NightShepherd.app"
PRODUCT="NightShepherd"
ROOT="$(pwd)"

CONFIG="${1:-release}"
ARCH="arm64"

echo "==> Building Swift package ($CONFIG, $ARCH)"
swift build -c "$CONFIG" --arch "$ARCH"

BIN_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"

if [ ! -x "$BIN_DIR/$PRODUCT" ]; then
    echo "ERROR: expected binary not found at $BIN_DIR/$PRODUCT" >&2
    exit 1
fi

echo "==> Generating app icon (if AppIcon.icns missing)"
if [ ! -f "AppIcon.icns" ] && [ -f "AppIcon.png" ]; then
    bash ./scripts/make-icns.sh AppIcon.png AppIcon.icns
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
chmod +x "$APP/Contents/MacOS/$PRODUCT"

# Copy resources straight to Contents/Resources/ so Bundle.main can find them.
# We deliberately do NOT copy SwiftPM's NightShepherd_NightShepherd.bundle into
# Contents/MacOS/ — it's a flat directory that confuses codesign.
if [ -d "$BIN_DIR/${PRODUCT}_${PRODUCT}.bundle" ]; then
    cp -R "$BIN_DIR/${PRODUCT}_${PRODUCT}.bundle/." "$APP/Contents/Resources/"
fi

cp Info.plist "$APP/Contents/Info.plist"
plutil -convert binary1 "$APP/Contents/Info.plist"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing"
codesign --force --sign - \
    --entitlements NightShepherd.entitlements \
    "$APP"

echo "==> Verifying signature"
codesign --verify --verbose=2 "$APP" || true

# Force Launch Services to re-read the bundle so LSUIElement etc. take effect.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$ROOT/$APP" >/dev/null 2>&1 || true

echo ""
echo "Built: $ROOT/$APP"
echo ""
echo "Run with:   open \"$ROOT/$APP\""
echo "Install with: cp -R \"$ROOT/$APP\" /Applications/"
