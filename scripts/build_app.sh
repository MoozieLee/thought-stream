#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/ThoughtStream.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCES_SOURCE_DIR="$ROOT_DIR/Resources"
HOME_DIR="$ROOT_DIR/.home"
MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.thoughtstream.app}"
APP_EXECUTABLE="ThoughtStreamApp"
CLI_EXECUTABLE="thought"

sanitize_bundle() {
  local bundle_path="$1"
  xattr -cr "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$bundle_path" 2>/dev/null || true
  xattr -dr com.apple.ResourceFork "$bundle_path" 2>/dev/null || true
}

mkdir -p "$HOME_DIR" "$MODULE_CACHE_DIR" "$DIST_DIR"

# Recreate dependency working copies from cache before packaging. On this
# machine, stale SwiftPM checkouts can hang on `git status` during release
# builds, while fresh working copies resolve and build normally.
rm -rf "$BUILD_DIR/checkouts/swift-syntax" "$BUILD_DIR/checkouts/swift-testing"

# Warm dependency checkouts before building products. This keeps dependency
# repair in a single explicit step before app/CLI compilation starts.
env HOME="$HOME_DIR" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  swift package resolve

env HOME="$HOME_DIR" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  swift build -c "$BUILD_CONFIGURATION" --product "$APP_EXECUTABLE"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$BUILD_CONFIGURATION/$APP_EXECUTABLE" "$MACOS_DIR/$APP_EXECUTABLE"
chmod +x "$MACOS_DIR/$APP_EXECUTABLE"

# Build CLI and embed into app bundle
env HOME="$HOME_DIR" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  swift build -c "$BUILD_CONFIGURATION" --product "$CLI_EXECUTABLE"

cp "$BUILD_DIR/$BUILD_CONFIGURATION/$CLI_EXECUTABLE" "$MACOS_DIR/$CLI_EXECUTABLE"
chmod +x "$MACOS_DIR/$CLI_EXECUTABLE"

if [[ -f "$RESOURCES_SOURCE_DIR/AppIcon.icns" ]]; then
  cp "$RESOURCES_SOURCE_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ -f "$RESOURCES_SOURCE_DIR/status/MenuBarIconTemplate.png" ]]; then
  cp "$RESOURCES_SOURCE_DIR/status/MenuBarIconTemplate.png" "$RESOURCES_DIR/MenuBarIconTemplate.png"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>ThoughtStreamApp</string>
  <key>CFBundleIdentifier</key>
  <string>com.thoughtstream.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>ThoughtStream</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

/usr/bin/plutil -replace CFBundleExecutable -string "$APP_EXECUTABLE" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -replace CFBundleIdentifier -string "$APP_BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$APP_BUILD" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -replace CFBundleIconFile -string "AppIcon" "$CONTENTS_DIR/Info.plist"

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

sanitize_bundle "$APP_DIR"
codesign --force --sign - "$MACOS_DIR/$APP_EXECUTABLE" >/dev/null
codesign --force --sign - "$MACOS_DIR/$CLI_EXECUTABLE" >/dev/null
codesign --force --sign - "$APP_DIR" >/dev/null
sanitize_bundle "$APP_DIR"

echo "Built app bundle at: $APP_DIR"
