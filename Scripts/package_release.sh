#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Time Zone Switcher"
VERSION="${VERSION:-0.1.1}"
ARCHIVE_NAME="Time-Zone-Switcher-v${VERSION}-macOS26-arm64"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/dist/releases"
ZIP_PATH="$RELEASE_DIR/$ARCHIVE_NAME.zip"
SHA_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/build_app.sh" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ZIP_PATH"
(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$SHA_PATH")"
)

echo "$ZIP_PATH"
echo "$SHA_PATH"
