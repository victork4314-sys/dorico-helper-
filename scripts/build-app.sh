#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Dorico Xbox Bridge must be packaged on macOS." >&2
  exit 1
fi

# These guards are intentionally independent of Swift tests. Packaging must stop
# if required controller delivery, mapping safety, or voice startup protection is removed.
bash scripts/verify-controller-routing.sh
bash scripts/verify-arbitrary-mappings.sh
bash scripts/verify-voice-startup.sh

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

MIC_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$CONTENTS/Info.plist")"
SPEECH_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSSpeechRecognitionUsageDescription' "$CONTENTS/Info.plist")"
[[ -n "$MIC_DESCRIPTION" ]] || { echo "Packaged app has no microphone usage description" >&2; exit 1; }
[[ -n "$SPEECH_DESCRIPTION" ]] || { echo "Packaged app has no speech-recognition usage description" >&2; exit 1; }

lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS/DoricoXboxBridge"
chmod 755 "$MACOS/DoricoXboxBridge"
lipo "$MACOS/DoricoXboxBridge" -verify_arch arm64 x86_64
lipo -info "$MACOS/DoricoXboxBridge"

cp README.md "$RESOURCES/README.md"
if [[ -d docs ]]; then
  cp -R docs "$RESOURCES/docs"
fi

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="dist/Dorico-Xbox-Bridge-macOS-Universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
unzip -t "$ZIP"

ZIP_VERIFY="$(mktemp -d)"
ditto -x -k "$ZIP" "$ZIP_VERIFY"
codesign --verify --deep --strict --verbose=2 "$ZIP_VERIFY/Dorico Xbox Bridge.app"
lipo "$ZIP_VERIFY/Dorico Xbox Bridge.app/Contents/MacOS/DoricoXboxBridge" -verify_arch arm64 x86_64
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$ZIP_VERIFY/Dorico Xbox Bridge.app/Contents/Info.plist")" ]]
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :NSSpeechRecognitionUsageDescription' "$ZIP_VERIFY/Dorico Xbox Bridge.app/Contents/Info.plist")" ]]
rm -rf "$ZIP_VERIFY"

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
DMG_VERIFY="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$DMG_VERIFY" "$DMG" >/dev/null
codesign --verify --deep --strict --verbose=2 "$DMG_VERIFY/Dorico Xbox Bridge.app"
lipo "$DMG_VERIFY/Dorico Xbox Bridge.app/Contents/MacOS/DoricoXboxBridge" -verify_arch arm64 x86_64
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$DMG_VERIFY/Dorico Xbox Bridge.app/Contents/Info.plist")" ]]
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :NSSpeechRecognitionUsageDescription' "$DMG_VERIFY/Dorico Xbox Bridge.app/Contents/Info.plist")" ]]
hdiutil detach "$DMG_VERIFY" >/dev/null
rmdir "$DMG_VERIFY"

COMMIT_SHA="${SOURCE_COMMIT_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}}"
cat > dist/BUILD-MANIFEST.txt <<EOF
Dorico Xbox Bridge validated build
Build number: $BUILD_NUMBER
Commit: $COMMIT_SHA
macOS runner: $(sw_vers -productVersion)
Swift: $(swift --version | head -n 1)
Architectures: arm64 + x86_64
Controller transport: GameController callbacks + 60 Hz direct polling backup
Recovery: background reassertion + app-switch recovery + sleep/wake recovery + reconnect recovery + watchdog
Voice startup: privacy descriptions verified + contextual strings capped at 100 + microphone format guarded + tap lifecycle tracked
ZIP: tested, extracted, signature verified, architectures verified, voice privacy metadata verified
DMG: verified, mounted, signature verified, architectures verified, voice privacy metadata verified
EOF

(
  cd dist
  shasum -a 256 \
    Dorico-Xbox-Bridge-macOS-Universal.zip \
    Dorico-Xbox-Bridge-macOS-Universal.dmg \
    > SHA256SUMS.txt
)

cat dist/BUILD-MANIFEST.txt
cat dist/SHA256SUMS.txt

echo "Created $APP"
echo "Created $ZIP"
echo "Created $DMG"
echo "Created dist/BUILD-MANIFEST.txt"
echo "Created dist/SHA256SUMS.txt"
