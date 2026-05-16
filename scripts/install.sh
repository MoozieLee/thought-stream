#!/bin/sh
set -eu

REPO="liyipeng/thought-stream"
INSTALL_DIR="/Applications"
CLI_SYMLINK="/usr/local/bin/thought"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

info()  { printf "${BOLD}%s${NC}\n" "$*"; }
ok()    { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
warn()  { printf "  ${YELLOW}⚠${NC}  %s\n" "$*"; }
fail()  { printf "  ${RED}✗${NC}  %s\n" "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
info "ThoughtStream Installer"

ARCH=""
case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  arm64)  ARCH="arm64"  ;;
  *)      fail "Unsupported architecture: $(uname -m)" ;;
esac

case "$(uname -s)" in
  Darwin) ;;
  *)      fail "ThoughtStream is currently macOS-only." ;;
esac

ok "Detected macOS / $ARCH"

# ---------------------------------------------------------------------------
# Fetch latest release
# ---------------------------------------------------------------------------
info "Fetching latest release..."

LATEST=$(curl -sfL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | grep '"tag_name":' \
  | head -1 \
  | sed 's/.*"tag_name": "//;s/".*//')

if [ -z "$LATEST" ]; then
  fail "Could not find latest release. Is the repo published?"
fi

ok "Latest version: $LATEST"

# ---------------------------------------------------------------------------
# Download DMG
# ---------------------------------------------------------------------------
DMG_NAME="ThoughtStream-${LATEST}-${ARCH}.dmg"
DMG_URL="https://github.com/$REPO/releases/download/$LATEST/$DMG_NAME"
DMG_PATH="$TMP_DIR/$DMG_NAME"

info "Downloading $DMG_NAME ..."
curl -fL# "$DMG_URL" -o "$DMG_PATH" 2>&1 | tail -1
ok "Downloaded to $DMG_PATH"

# ---------------------------------------------------------------------------
# Verify checksum
# ---------------------------------------------------------------------------
CHECKSUM_NAME="ThoughtStream-${LATEST}-checksums.txt"
CHECKSUM_URL="https://github.com/$REPO/releases/download/$LATEST/$CHECKSUM_NAME"
CHECKSUM_PATH="$TMP_DIR/$CHECKSUM_NAME"

if curl -sfL "$CHECKSUM_URL" -o "$CHECKSUM_PATH" 2>/dev/null; then
  EXPECTED=$(grep "$DMG_NAME" "$CHECKSUM_PATH" | head -1 | awk '{print $1}')
  if [ -n "$EXPECTED" ]; then
    ACTUAL=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
      ok "Checksum verified"
    else
      fail "Checksum mismatch! Expected $EXPECTED, got $ACTUAL"
    fi
  else
    warn "No checksum entry for $DMG_NAME in $CHECKSUM_NAME"
  fi
else
  warn "Could not download checksums file (non-fatal)"
fi

# ---------------------------------------------------------------------------
# Mount DMG and install .app
# ---------------------------------------------------------------------------
info "Installing ThoughtStream.app ..."

MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse 2>/dev/null \
  | grep '/Volumes/' \
  | sed 's/.*\/Volumes\//\/Volumes\//' \
  | head -1)

if [ -z "$MOUNT_POINT" ]; then
  fail "Failed to mount DMG."
fi

# Remove old version if exists
if [ -d "$INSTALL_DIR/ThoughtStream.app" ]; then
  warn "Removing previous installation..."
  rm -rf "$INSTALL_DIR/ThoughtStream.app"
fi

ditto "$MOUNT_POINT/ThoughtStream.app" "$INSTALL_DIR/ThoughtStream.app"
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null

ok "Installed to $INSTALL_DIR/ThoughtStream.app"

# ---------------------------------------------------------------------------
# Create CLI symlink
# ---------------------------------------------------------------------------
CLI_SOURCE="$INSTALL_DIR/ThoughtStream.app/Contents/MacOS/thought"
if [ -f "$CLI_SOURCE" ]; then
  if [ ! -f "$CLI_SYMLINK" ]; then
    if ln -sf "$CLI_SOURCE" "$CLI_SYMLINK" 2>/dev/null; then
      ok "CLI symlink created: $CLI_SYMLINK"
    else
      warn "Could not create symlink at $CLI_SYMLINK (permission denied)."
      printf "  Run this manually: sudo ln -sf \"%s\" %s\n" "$CLI_SOURCE" "$CLI_SYMLINK"
    fi
  else
    ok "CLI symlink already exists: $CLI_SYMLINK"
  fi
else
  warn "CLI binary not found in bundle. Run build script to embed it."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n"
info "ThoughtStream $LATEST installed!"
printf "\n"
printf "  Open with:     Shift + Command + Space\n"
printf "  CLI command:   thought\n"
printf "\n"
