#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="ThoughtStream.app"
APP_PATH="$DIST_DIR/$APP_NAME"
ZIP_PATH="$DIST_DIR/ThoughtStream.zip"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.thoughtstream.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
CREATE_DMG="${CREATE_DMG:-1}"

BUILD_SCRIPT="$ROOT_DIR/scripts/build_app.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/create_dmg.sh"
VALIDATE_SCRIPT="$ROOT_DIR/scripts/validate_release.sh"

BUILD_CONFIGURATION="$BUILD_CONFIGURATION" \
APP_VERSION="$APP_VERSION" \
APP_BUILD="$APP_BUILD" \
APP_BUNDLE_ID="$APP_BUNDLE_ID" \
"$BUILD_SCRIPT"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing app bundle with: $SIGNING_IDENTITY"
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH/Contents/MacOS/ThoughtStreamApp" >/dev/null
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH" >/dev/null
fi

"$VALIDATE_SCRIPT" "$APP_PATH"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "Created ZIP at: $ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "NOTARY_PROFILE requires SIGNING_IDENTITY." >&2
    exit 1
  fi

  echo "Submitting ZIP for notarization with profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  echo "Stapled app and rebuilt ZIP."
fi

if [[ "$CREATE_DMG" == "1" ]]; then
  SIGNING_IDENTITY="$SIGNING_IDENTITY" "$DMG_SCRIPT"
fi

echo
echo "Release artifacts:"
echo "- $APP_PATH"
echo "- $ZIP_PATH"
if [[ "$CREATE_DMG" == "1" ]]; then
  echo "- $DIST_DIR/ThoughtStream.dmg"
fi
