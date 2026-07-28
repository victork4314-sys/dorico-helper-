#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Dorico Xbox Bridge must be packaged on macOS." >&2
  exit 1
fi

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  swift test
fi

rm -rf .build-arm64 .build-x86_64 dist
mkdir -p dist

swift build -c release --arch arm64 --scratch-path .build-arm64
ARM_BIN_DIR="$(swift build -c release --arch arm64 --scratch-path .build-arm64 --show-bin-path)"

swift build -c release --arch x86_64 --scratch-path .build-x86_64
INTEL_BIN_DIR="$(swift build -c release --arch x86_64 --scratch-path .build-x86_64 --show-bin-path)"

ARM_BINARY="$ARM_BIN_DIR/DoricoXboxBridge"
INTEL_BINARY="$INTEL_BIN_DIR/DoricoXboxBridge"
APP="dist/Dorico Xbox Bridge.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS" "$RESOURCES"
cp packaging/Info.plist "$CONTENTS/Info.plist"

BUILD_NUMBER="${BUILD_NUMBER:-1}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist"

lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS/DoricoXboxBridge"
chmod 755 "$MACOS/DoricoXboxBridge"
lipo -verify_arch arm64 x86_64 "$MACOS/DoricoXboxBridge"
lipo -info "$MACOS/DoricoXboxBridge"

cp README.md "$RESOURCES/README.md"
if [[ -d docs ]]; then
  cp -R docs "$RESOURCES/docs"
fi

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="dist/Dorico-Xbox-Bridge-macOS-Universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

DMG_ROOT="dist/dmg-root"
DMG="dist/Dorico-Xbox-Bridge-macOS-Universal.dmg"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "Dorico Xbox Bridge" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG"
rm -rf "$DMG_ROOT"

hdiutil verify "$DMG"

echo "Created $APP"
echo "Created $ZIP"
echo "Created $DMG"
