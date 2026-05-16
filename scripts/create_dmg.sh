#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="ThoughtStream.app"
APP_PATH="${APP_PATH:-$DIST_DIR/$APP_NAME}"
DMG_NAME="${DMG_NAME:-ThoughtStream.dmg}"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="${VOLUME_NAME:-ThoughtStream}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
STAGING_DIR="$DIST_DIR/.dmg-staging"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH" >/dev/null
fi

rm -rf "$STAGING_DIR"

echo "Created DMG at: $DMG_PATH"
