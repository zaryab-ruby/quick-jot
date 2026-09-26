#!/usr/bin/env bash
# Packages build/QuickJot.app into build/QuickJot-<version>.dmg with a drag-to-Applications layout.
# Usage: scripts/make-dmg.sh   (run scripts/build-app.sh first, or use `make dmg`)
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/QuickJot.app"
[[ -d "$APP" ]] || { echo "Missing $APP. Run scripts/build-app.sh first." >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/QuickJot-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "QuickJot $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
