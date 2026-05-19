#!/bin/sh
set -eu

REPO="MoozieLee/thought-stream"
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

API_RESPONSE=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: ThoughtStream-Installer" \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)

LATEST=$(printf "%s" "$API_RESPONSE" \
  | grep '"tag_name":' \
  | head -1 \
  | sed 's/.*"tag_name": "//;s/".*//')

if [ -z "$LATEST" ]; then
  LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest" 2>/dev/null || true)
  case "$LATEST_URL" in
    */tag/*)
      LATEST=${LATEST_URL##*/}
      ;;
  esac
fi

if [ -z "$LATEST" ]; then
  fail "Could not find latest release from GitHub API or release redirect."
fi

ok "Latest version: $LATEST"

# Strip leading 'v' from tag to get version string (used in artifact names)
VERSION="${LATEST#v}"

# ---------------------------------------------------------------------------
# Download release artifact
# ---------------------------------------------------------------------------
FORMAT=""
ARTIFACT_NAME="ThoughtStream-${VERSION}-${ARCH}.dmg"
ARTIFACT_URL="https://github.com/$REPO/releases/download/$LATEST/$ARTIFACT_NAME"
ARTIFACT_PATH="$TMP_DIR/$ARTIFACT_NAME"

info "Downloading $ARTIFACT_NAME ..."
HTTP_CODE=$(curl -sL -w '%{http_code}' "$ARTIFACT_URL" -o "$ARTIFACT_PATH" --show-error 2>&1 || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  FORMAT="dmg"
else
  # Fall back to ZIP
  rm -f "$ARTIFACT_PATH"
  ARTIFACT_NAME="ThoughtStream.zip"
  ARTIFACT_URL="https://github.com/$REPO/releases/download/$LATEST/$ARTIFACT_NAME"
  ARTIFACT_PATH="$TMP_DIR/$ARTIFACT_NAME"

  info "Falling back to $ARTIFACT_NAME ..."
  curl -fsSL --show-error "$ARTIFACT_URL" -o "$ARTIFACT_PATH" 2>&1
  FORMAT="zip"
fi

ok "Downloaded $ARTIFACT_NAME"

# ---------------------------------------------------------------------------
# Verify checksum
# ---------------------------------------------------------------------------
CHECKSUM_NAME="ThoughtStream-${VERSION}-checksums.txt"
CHECKSUM_URL="https://github.com/$REPO/releases/download/$LATEST/$CHECKSUM_NAME"
CHECKSUM_PATH="$TMP_DIR/$CHECKSUM_NAME"

if curl -sfL "$CHECKSUM_URL" -o "$CHECKSUM_PATH" 2>/dev/null; then
  EXPECTED=$(grep "$ARTIFACT_NAME" "$CHECKSUM_PATH" | head -1 | awk '{print $1}')
  if [ -n "$EXPECTED" ]; then
    ACTUAL=$(shasum -a 256 "$ARTIFACT_PATH" | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
      ok "Checksum verified"
    else
      fail "Checksum mismatch! Expected $EXPECTED, got $ACTUAL"
    fi
  else
    warn "No checksum entry for $ARTIFACT_NAME in $CHECKSUM_NAME"
  fi
else
  warn "Could not download checksums file (non-fatal)"
fi

# ---------------------------------------------------------------------------
# Install .app
# ---------------------------------------------------------------------------
info "Installing ThoughtStream.app ..."

# Kill existing app before replacing
if pgrep -x "ThoughtStreamApp" >/dev/null 2>&1; then
  pkill -x "ThoughtStreamApp" 2>/dev/null || true
  sleep 0.5
fi

# Remove old version if exists
if [ -d "$INSTALL_DIR/ThoughtStream.app" ]; then
  warn "Removing previous installation..."
  rm -rf "$INSTALL_DIR/ThoughtStream.app"
fi

case "$FORMAT" in
  dmg)
    MOUNT_POINT=$(hdiutil attach "$ARTIFACT_PATH" -nobrowse 2>/dev/null \
      | grep '/Volumes/' \
      | sed 's/.*\/Volumes\//\/Volumes\//' \
      | head -1)
    if [ -z "$MOUNT_POINT" ]; then
      fail "Failed to mount DMG."
    fi
    ditto "$MOUNT_POINT/ThoughtStream.app" "$INSTALL_DIR/ThoughtStream.app"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
    ;;
  zip)
    unzip -q "$ARTIFACT_PATH" -d "$TMP_DIR/app-extract"
    ditto "$TMP_DIR/app-extract/ThoughtStream.app" "$INSTALL_DIR/ThoughtStream.app"
    ;;
esac

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
