#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/ThoughtStream.app}"
STRICT_GATEKEEPER="${STRICT_GATEKEEPER:-0}"

STAGING_ROOT="$(mktemp -d /private/tmp/thoughtstream-validate.XXXXXX)"
STAGED_APP_PATH="$STAGING_ROOT/$(basename "$APP_PATH")"

cleanup() {
  rm -rf "$STAGING_ROOT"
}

sanitize_bundle() {
  local bundle_path="$1"
  xattr -cr "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.ResourceFork "$bundle_path" 2>/dev/null || true
}

trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  exit 1
fi

ditto "$APP_PATH" "$STAGED_APP_PATH"
sanitize_bundle "$STAGED_APP_PATH"

INFO_PLIST="$STAGED_APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$STAGED_APP_PATH/Contents/MacOS/ThoughtStreamApp"

echo "Inspecting: $APP_PATH"
echo
echo "Info.plist"
plutil -p "$INFO_PLIST"
echo
echo "Bundle signature"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP_PATH"
echo
echo "Signing details"
codesign -dvvv "$STAGED_APP_PATH" 2>&1
echo

if spctl -a -vv "$STAGED_APP_PATH"; then
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

CLI_PATH="$STAGED_APP_PATH/Contents/MacOS/thought"
if [[ -x "$CLI_PATH" ]]; then
  echo "CLI binary present: $CLI_PATH"
else
  echo "Missing CLI binary at: $CLI_PATH" >&2
  exit 1
fi
