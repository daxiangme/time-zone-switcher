#!/usr/bin/env bash
set -euo pipefail

# Renders the popover and settings window to PNGs (zh/en, dark/light) with fake state.
# Usage: Scripts/snapshot.sh [output-dir]   (default: .build/snapshots)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/.build/snapshots}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
PACKAGE_DIR="$ROOT_DIR/.build/snapshot-package"

# The app views live in an executable target that can't be imported, so assemble a
# throwaway package that links the same sources next to the snapshot entry point.
rm -rf "$PACKAGE_DIR/Sources"
mkdir -p "$PACKAGE_DIR/Sources/Snapshot"
ln -s "$ROOT_DIR/Sources/TimeZoneCore" "$PACKAGE_DIR/Sources/TimeZoneCore"
for source in "$ROOT_DIR"/Sources/TimeZoneBar/*.swift; do
  # TimeZoneBarApp.swift holds @main; the snapshot tool brings its own entry point.
  [ "$(basename "$source")" = "TimeZoneBarApp.swift" ] && continue
  ln -s "$source" "$PACKAGE_DIR/Sources/Snapshot/$(basename "$source")"
done
ln -s "$ROOT_DIR/Scripts/snapshot/main.swift" "$PACKAGE_DIR/Sources/Snapshot/main.swift"

cat > "$PACKAGE_DIR/Package.swift" <<'EOF'
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Snapshot",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .target(name: "TimeZoneCore"),
        .executableTarget(name: "Snapshot", dependencies: ["TimeZoneCore"])
    ]
)
EOF

swift build --package-path "$PACKAGE_DIR" --product Snapshot
BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"

# AppLocalization looks up .lproj folders in Bundle.main, which is the binary's directory here.
cp -R "$ROOT_DIR/Resources/Localizations/"* "$BIN_DIR/"

"$BIN_DIR/Snapshot" "$OUTPUT_DIR"
