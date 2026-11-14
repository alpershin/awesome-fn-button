#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
VERSION="0.1.0"
ARCH="${FN_BUILD_ARCH:-$(uname -m)}"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac

swift build -c release --arch "$ARCH" --scratch-path build/swift
BIN_DIR="$(swift build -c release --arch "$ARCH" --scratch-path build/swift --show-bin-path)"
APP="build/packaging/Awesome Fn Button.app"
OUT="build/releases"
BASE="awesome-fn-button-${VERSION}-${ARCH}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT"
cp "$BIN_DIR/AwesomeFnButton" "$APP/Contents/MacOS/AwesomeFnButton"
cp Resources/Info.plist "$APP/Contents/Info.plist"
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
# An ad hoc signature needs no certificate or Apple account; Gatekeeper still requires an exception.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

STAGE="build/dmg-stage"
mkdir -p "$STAGE"
# This directory is dedicated to packaging; never remove the user's installed app.
if [[ -e "$STAGE/Awesome Fn Button.app" ]]; then
    rm -rf "$STAGE/Awesome Fn Button.app"
fi
ditto "$APP" "$STAGE/Awesome Fn Button.app"
ln -sfn /Applications "$STAGE/Applications"
cp docs/INSTALL.txt "$STAGE/READ ME.txt"
cp LICENSE "$STAGE/LICENSE.txt"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$BASE.zip"
hdiutil create -ov -format UDZO -volname "Awesome Fn Button" -srcfolder "$STAGE" "$OUT/$BASE.dmg"
(
    cd "$OUT"
    shasum -a 256 "$BASE.dmg" "$BASE.zip" > "$BASE.sha256"
)
printf 'Artifacts: %s/%s/%s\n' "$PROJECT_DIR" "$OUT" "$BASE.*"
