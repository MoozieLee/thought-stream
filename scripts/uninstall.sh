#!/bin/sh
set -eu

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

info()  { printf "${BOLD}%s${NC}\n" "$*"; }
ok()    { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
warn()  { printf "  ${YELLOW}⚠${NC}  %s\n" "$*"; }
fail()  { printf "  ${RED}✗${NC}  %s\n" "$*"; }

info "ThoughtStream Uninstaller"

REMOVED=false

# ---------------------------------------------------------------------------
# Remove CLI symlink
# ---------------------------------------------------------------------------
if [ -L /usr/local/bin/thought ] || [ -f /usr/local/bin/thought ]; then
  if rm -f /usr/local/bin/thought 2>/dev/null; then
    ok "Removed CLI symlink: /usr/local/bin/thought"
    REMOVED=true
  else
    warn "Could not remove /usr/local/bin/thought (permission denied)."
    printf "  Run: sudo rm /usr/local/bin/thought\n"
  fi
else
  warn "CLI symlink not found: /usr/local/bin/thought"
fi

# ---------------------------------------------------------------------------
# Remove app bundle
# ---------------------------------------------------------------------------
APP_PATH="/Applications/ThoughtStream.app"
if [ -d "$APP_PATH" ]; then
  # Try graceful shutdown first
  pkill -x "ThoughtStreamApp" 2>/dev/null || true
  sleep 0.5

  if rm -rf "$APP_PATH" 2>/dev/null; then
    ok "Removed app: $APP_PATH"
    REMOVED=true
  else
    warn "Could not remove $APP_PATH (permission denied)."
    printf "  Run: sudo rm -rf \"$APP_PATH\"\n"
  fi
else
  warn "App not found: $APP_PATH"
fi

# ---------------------------------------------------------------------------
# Optionally remove local data
# ---------------------------------------------------------------------------
DATA_DIR="$HOME/Library/Application Support/ThoughtStream"
if [ -d "$DATA_DIR" ]; then
  printf "\n"
  info "Local data found at: $DATA_DIR"
  printf "  This includes all your captured thoughts.\n"
  printf "  Delete it? [y/N] "
  read -r CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES)
      rm -rf "$DATA_DIR"
      ok "Removed local data: $DATA_DIR"
      REMOVED=true
      ;;
    *)
      warn "Skipped data removal: $DATA_DIR"
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n"
if [ "$REMOVED" = true ]; then
  info "ThoughtStream has been uninstalled."
else
  warn "Nothing was removed."
fi
