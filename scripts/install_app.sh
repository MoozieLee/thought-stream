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

# Create CLI symlink: try without sudo first, fall back to sudo
CLI_SOURCE="$TARGET_APP/Contents/MacOS/thought"
if [[ -x "$CLI_SOURCE" && ! -f /usr/local/bin/thought ]]; then
  if ln -sf "$CLI_SOURCE" /usr/local/bin/thought 2>/dev/null; then
    echo "CLI symlink created: /usr/local/bin/thought"
  else
    echo "Creating CLI symlink at /usr/local/bin/thought (requires sudo)..."
    sudo ln -sf "$CLI_SOURCE" /usr/local/bin/thought
    echo "CLI symlink created: /usr/local/bin/thought"
  fi
fi

open "$TARGET_APP"

echo "Installed and opened: $TARGET_APP"
