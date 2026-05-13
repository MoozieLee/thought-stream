#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ThoughtStream.app"
APP_PROCESS_NAME="ThoughtStreamApp"
BUILD_SCRIPT="$ROOT_DIR/scripts/build_app.sh"
DIST_APP="$ROOT_DIR/dist/$APP_NAME"
INSTALL_DIR="/Applications"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

"$BUILD_SCRIPT"

if pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_PROCESS_NAME" || true

  for _ in {1..20}; do
    if ! pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

rm -rf "$TARGET_APP"
cp -R "$DIST_APP" "$TARGET_APP"
open "$TARGET_APP"

echo "Installed and opened: $TARGET_APP"
