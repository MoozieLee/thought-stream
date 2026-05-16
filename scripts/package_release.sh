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
RELEASE_VERSION="${APP_VERSION}-b${APP_BUILD}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.thoughtstream.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
CREATE_DMG="${CREATE_DMG:-1}"
RELEASE_WORK_DIR="$(mktemp -d /private/tmp/thoughtstream-release.XXXXXX)"
STAGED_APP_PATH="$RELEASE_WORK_DIR/$APP_NAME"
REPO="${REPO:-}"

BUILD_SCRIPT="$ROOT_DIR/scripts/build_app.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/create_dmg.sh"
VALIDATE_SCRIPT="$ROOT_DIR/scripts/validate_release.sh"

cleanup() {
  rm -rf "$RELEASE_WORK_DIR"
}

sanitize_bundle() {
  local bundle_path="$1"
  xattr -cr "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.ResourceFork "$bundle_path" 2>/dev/null || true
}

resolve_repo_slug() {
  if [[ -n "$REPO" ]]; then
    echo "$REPO"
    return
  fi

  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "$remote_url" =~ ^git@github\.com:(.+)\.git$ ]]; then
    echo "${match[1]}"
    return
  fi
  if [[ "$remote_url" =~ ^https://github\.com/(.+)\.git$ ]]; then
    echo "${match[1]}"
    return
  fi
  if [[ "$remote_url" =~ ^https://github\.com/(.+)$ ]]; then
    echo "${match[1]}"
    return
  fi
}

trap cleanup EXIT

REPO="$(resolve_repo_slug)"

BUILD_CONFIGURATION="$BUILD_CONFIGURATION" \
APP_VERSION="$APP_VERSION" \
APP_BUILD="$APP_BUILD" \
APP_BUNDLE_ID="$APP_BUNDLE_ID" \
"$BUILD_SCRIPT"

ditto "$APP_PATH" "$STAGED_APP_PATH"
sanitize_bundle "$STAGED_APP_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing app bundle with: $SIGNING_IDENTITY"
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$STAGED_APP_PATH/Contents/MacOS/ThoughtStreamApp" >/dev/null
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$STAGED_APP_PATH" >/dev/null
fi

"$VALIDATE_SCRIPT" "$STAGED_APP_PATH"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$STAGED_APP_PATH" "$ZIP_PATH"
echo "Created ZIP at: $ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "NOTARY_PROFILE requires SIGNING_IDENTITY." >&2
    exit 1
  fi

  echo "Submitting ZIP for notarization with profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$STAGED_APP_PATH"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$STAGED_APP_PATH" "$ZIP_PATH"
  echo "Stapled app and rebuilt ZIP."
fi

if [[ "$CREATE_DMG" == "1" ]]; then
  APP_PATH="$STAGED_APP_PATH" \
  SIGNING_IDENTITY="$SIGNING_IDENTITY" \
  APP_VERSION="$RELEASE_VERSION" \
  "$DMG_SCRIPT"
fi

# ---------------------------------------------------------------------------
# Generate checksums
# ---------------------------------------------------------------------------
CHECKSUM_FILE="$DIST_DIR/ThoughtStream-${RELEASE_VERSION}-checksums.txt"
rm -f "$CHECKSUM_FILE"
{
  if [[ -f "$ZIP_PATH" ]]; then
    shasum -a 256 "$ZIP_PATH"
  fi
  if [[ "$CREATE_DMG" == "1" ]]; then
    shasum -a 256 "$(ls "$DIST_DIR"/*.dmg 2>/dev/null | head -1)"
  fi
} | while read -r hash artifact_path; do
  echo "$hash  $(basename "$artifact_path")"
done > "$CHECKSUM_FILE"

echo "Generated checksums at: $CHECKSUM_FILE"

# ---------------------------------------------------------------------------
# Upload to GitHub Releases
# ---------------------------------------------------------------------------
RELEASE_TAG="v${RELEASE_VERSION}"

# Ensure tag exists on remote before creating release
git tag -f "$RELEASE_TAG" >/dev/null 2>&1
git push origin "$RELEASE_TAG" >/dev/null 2>&1 || {
  echo "Warning: could not push tag $RELEASE_TAG, continuing..." >&2
}

if command -v gh &>/dev/null; then
  echo "Creating GitHub release: $RELEASE_TAG"

  if gh release view "$RELEASE_TAG" &>/dev/null 2>&1; then
    echo "Release $RELEASE_TAG already exists, uploading artifacts..."
  else
    gh release create "$RELEASE_TAG" \
      --title "ThoughtStream $RELEASE_VERSION" \
      --notes "See [CHANGELOG](https://github.com/liyipeng/thought-stream/blob/main/CHANGELOG.md) for details." \
      --target main \
      --draft
  fi

  gh release upload "$RELEASE_TAG" "$ZIP_PATH" --clobber
  if [[ "$CREATE_DMG" == "1" ]]; then
    DMG_PATH="$DIST_DIR/ThoughtStream-${RELEASE_VERSION}-$(uname -m).dmg"
    if [[ -f "$DMG_PATH" ]]; then
      gh release upload "$RELEASE_TAG" "$DMG_PATH" --clobber
    else
      echo "DMG not found at expected path: $DMG_PATH" >&2
    fi
  fi
  gh release upload "$RELEASE_TAG" "$CHECKSUM_FILE" --clobber

  if [[ -n "$REPO" ]]; then
    echo "Release published: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
  else
    echo "Release published: $RELEASE_TAG"
  fi
else
  echo "gh CLI not found. Release artifacts are ready at:"
  echo "  $DIST_DIR/"
  echo "To publish manually:"
  echo "  gh release create $RELEASE_TAG $DIST_DIR/* --title 'ThoughtStream $APP_VERSION'"
fi

echo
echo "Release artifacts:"
echo "- $APP_PATH"
echo "- $ZIP_PATH"
if [[ "$CREATE_DMG" == "1" ]]; then
  echo "- $DIST_DIR/ThoughtStream-${APP_VERSION}-*.dmg"
fi
echo "- $CHECKSUM_FILE"
