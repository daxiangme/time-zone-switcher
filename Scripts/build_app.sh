#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Time Zone Switcher"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"

swift test
swift build -c "$CONFIGURATION" --product TimeZoneBar

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/TimeZoneBar"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/TimeZoneBar"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -d "$ROOT_DIR/Resources/Localizations" ]; then
  cp -R "$ROOT_DIR/Resources/Localizations/"* "$APP_DIR/Contents/Resources/"
fi

chmod 755 "$APP_DIR/Contents/MacOS/TimeZoneBar"
codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
