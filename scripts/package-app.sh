#!/usr/bin/env bash
set -euo pipefail

EXECUTABLE_PATH="${1:-.build/release/DoricoXboxBridge}"
OUTPUT_DIRECTORY="${2:-dist}"
APP_NAME="Dorico Xbox Bridge"
APP_PATH="${OUTPUT_DIRECTORY}/${APP_NAME}.app"
DMG_STAGING="${OUTPUT_DIRECTORY}/dmg-root"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Missing executable: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

rm -rf "${OUTPUT_DIRECTORY}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_PATH}/Contents/MacOS/DoricoXboxBridge"
cp packaging/Info.plist "${APP_PATH}/Contents/Info.plist"
chmod +x "${APP_PATH}/Contents/MacOS/DoricoXboxBridge"

# Ad-hoc signing keeps the bundle internally consistent. A public release can
# replace this with Developer ID signing and notarization when credentials exist.
codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${APP_PATH}/Contents/Info.plist"

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${OUTPUT_DIRECTORY}/DoricoXboxBridge-macOS.zip"

mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"
hdiutil create \
  -volname "Dorico Xbox Bridge" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${OUTPUT_DIRECTORY}/DoricoXboxBridge-macOS.dmg"
rm -rf "${DMG_STAGING}"

printf 'Packaged:\n- %s\n- %s\n- %s\n' \
  "${APP_PATH}" \
  "${OUTPUT_DIRECTORY}/DoricoXboxBridge-macOS.zip" \
  "${OUTPUT_DIRECTORY}/DoricoXboxBridge-macOS.dmg"
