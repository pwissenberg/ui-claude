#!/usr/bin/env bash
#
# Builds "Claude Companion.app" from the Swift package - no Xcode required,
# just the Command Line Tools Swift toolchain.
#
#   ./build.sh            build the .app bundle into ./build.noindex
#   ./build.sh --run      build, then (re)launch it from ./build.noindex
#   ./build.sh --install  build, install to /Applications, and launch it there
#   ./build.sh --dist     build, package a release zip, and generate the Homebrew cask
#
set -euo pipefail

APP_NAME="Claude Companion"
BUNDLE_ID="co.rockflour.claudecompanion"
EXECUTABLE="ClaudeCompanion"
VERSION="0.1.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build.noindex"
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

# Any running copy has to go before we replace or relaunch it - two instances would
# fight over the ⌥Space hot key, and only one of them can win it.
quit_running() {
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    pkill -f "$APP_NAME.app/Contents/MacOS/$EXECUTABLE" >/dev/null 2>&1 || true
    sleep 0.5
}

case "${1:-}" in
--run)
    echo "==> Relaunching…"
    quit_running
    open "$APP_DIR"
    echo "==> Launched. Press ⌥Space to summon Claude."
    ;;
--install)
    # /Applications is the only location Spotlight indexes by default, and the only
    # one SMAppService will register a login item from.
    DEST="/Applications"
    if [[ ! -w "$DEST" ]]; then
        DEST="$HOME/Applications"
        mkdir -p "$DEST"
        echo "==> /Applications is not writable; installing to $DEST instead"
    fi

    echo "==> Installing to $DEST…"
    quit_running
    rm -rf "$DEST/$APP_NAME.app"
    cp -R "$APP_DIR" "$DEST/"
    # Re-sign in place: copying can invalidate the ad-hoc signature.
    codesign --force --sign - "$DEST/$APP_NAME.app"
    # Nudge Spotlight and Launch Services to notice it immediately.
    mdimport "$DEST/$APP_NAME.app" >/dev/null 2>&1 || true

    open "$DEST/$APP_NAME.app"
    echo "==> Installed and launched from $DEST"
    echo "==> Find it in Spotlight as \"$APP_NAME\". Press ⌥Space to summon Claude."
    echo "==> To start it automatically, use \"Start at Login\" in the menu-bar menu."
    ;;
--dist)
    # Release artefact for Homebrew Cask, plus the cask that points at it.
    DIST_DIR="$ROOT/dist"
    ZIP_NAME="ClaudeCompanion-$VERSION.zip"
    ZIP_PATH="$DIST_DIR/$ZIP_NAME"
    TAG="v$VERSION"

    mkdir -p "$DIST_DIR"
    rm -f "$ZIP_PATH"
    echo "==> Packaging $ZIP_NAME…"
    # ditto, not zip: it preserves the bundle's symlinks, extended attributes and
    # code signature, which a plain zip mangles.
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

    SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
    SIZE="$(du -h "$ZIP_PATH" | awk '{print $1}')"
    echo "==> $ZIP_PATH ($SIZE)"
    echo "==> sha256 $SHA"

    cat > "$DIST_DIR/claude-companion.rb" <<CASK
cask "claude-companion" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/pwissenberg/ui-claude/releases/download/v#{version}/ClaudeCompanion-#{version}.zip"
  name "$APP_NAME"
  desc "Floating companion window for Claude.ai, summoned with a hot key"
  homepage "https://github.com/pwissenberg/ui-claude"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/HTTPStorages/$BUNDLE_ID.binarycookies",
    "~/Library/Logs/ClaudeCompanion.log",
    "~/Library/Preferences/$BUNDLE_ID.plist",
    "~/Library/WebKit/$BUNDLE_ID",
  ]
end
CASK

    echo "==> Cask written: $DIST_DIR/claude-companion.rb"
    echo
    echo "Next steps (see README, \"Distributing via Homebrew\"):"
    echo "  1. gh release create $TAG \"$ZIP_PATH\" --repo pwissenberg/ui-claude \\"
    echo "       --title \"$APP_NAME $VERSION\" --notes \"…\""
    echo "  2. Copy dist/claude-companion.rb into a tap repo as Casks/claude-companion.rb"
    echo "  3. brew install --cask pwissenberg/tap/claude-companion"
    echo
    echo "The repository must be public for Homebrew to download the asset, and the"
    echo "app is ad-hoc signed, so Gatekeeper will quarantine it - see the README."
    ;;
esac
