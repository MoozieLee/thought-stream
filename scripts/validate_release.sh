#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/ThoughtStream.app}"
STRICT_GATEKEEPER="${STRICT_GATEKEEPER:-0}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/ThoughtStreamApp"

echo "Inspecting: $APP_PATH"
echo
echo "Info.plist"
plutil -p "$INFO_PLIST"
echo
echo "Bundle signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo
echo "Signing details"
codesign -dvvv "$APP_PATH" 2>&1
echo

if spctl -a -vv "$APP_PATH"; then
  echo
  echo "Gatekeeper assessment passed."
else
  echo
  echo "Gatekeeper assessment failed."
  if [[ "$STRICT_GATEKEEPER" == "1" ]]; then
    exit 1
  fi
  echo "This is expected for ad hoc or unsigned local builds."
fi

if [[ -x "$EXECUTABLE_PATH" ]]; then
  echo
  echo "Main executable present: $EXECUTABLE_PATH"
else
  echo "Missing main executable at: $EXECUTABLE_PATH" >&2
  exit 1
fi
