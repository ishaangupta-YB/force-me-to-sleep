#!/usr/bin/env bash
#
# Converts a 1024x1024 source PNG into a macOS .icns icon.
# Usage: make-icns.sh source.png output.icns
#
set -euo pipefail

SRC="${1:-AppIcon.png}"
OUT="${2:-AppIcon.icns}"

if [ ! -f "$SRC" ]; then
    echo "Source PNG not found: $SRC" >&2
    exit 1
fi

TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# Apple's required icon sizes for an .iconset
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"        >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"     >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"        >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"     >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"      >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png"   >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"      >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png"   >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"      >/dev/null
cp                "$SRC"        "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$TMP"

echo "Built: $OUT"
