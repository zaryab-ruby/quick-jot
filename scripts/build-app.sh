#!/usr/bin/env bash
# Builds QuickJot with SwiftPM and wraps the binary in build/QuickJot.app.
# Release builds are universal (Apple Silicon + Intel); debug builds are for this Mac only.
# Usage: scripts/build-app.sh [release|debug]
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP="build/QuickJot.app"
BINARY="build/QuickJot"
mkdir -p build

if [[ "$CONFIG" == "release" ]]; then
  slices=()
  for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch"
    slices+=(".build/$arch/release/QuickJot")
  done
  lipo -create "${slices[@]}" -output "$BINARY"
else
  swift build -c "$CONFIG"
  cp "$(swift build -c "$CONFIG" --show-bin-path)/QuickJot" "$BINARY"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$BINARY" "$APP/Contents/MacOS/QuickJot"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature so macOS treats it as a proper app (login item, URL scheme).
codesign --force --sign - --timestamp=none "$APP" >/dev/null

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/QuickJot"))"
