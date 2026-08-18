#!/usr/bin/env bash
#
# Builds "Claude Companion.app" from the Swift package - no Xcode required,
# just the Command Line Tools Swift toolchain.
#
#   ./build.sh          build the .app bundle into ./build
#   ./build.sh --run    build, then (re)launch the app
#
set -euo pipefail

APP_NAME="Claude Companion"
BUNDLE_ID="co.rockflour.claudecompanion"
EXECUTABLE="ClaudeCompanion"
VERSION="0.1.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "==> Compiling ($EXECUTABLE, release)…"
swift build -c release --package-path "$ROOT"
BIN_PATH="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$EXECUTABLE"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_PATH" "$CONTENTS/MacOS/$EXECUTABLE"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$EXECUTABLE</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <!-- Menu-bar-only app: no Dock icon, no app menu. -->
    <key>LSUIElement</key>             <true/>
    <!-- claudecompanion://toggle  - lets Raycast/Shortcuts/CLI summon the window. -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>    <string>$BUNDLE_ID</string>
            <key>CFBundleURLSchemes</key> <array><string>claudecompanion</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"

if [[ "${1:-}" == "--run" ]]; then
    echo "==> Relaunching…"
    # Quit any running instance first so the new build takes over.
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    pkill -f "$APP_NAME.app/Contents/MacOS/$EXECUTABLE" >/dev/null 2>&1 || true
    sleep 0.5
    open "$APP_DIR"
    echo "==> Launched. Press ⌥Space to summon Claude."
fi
