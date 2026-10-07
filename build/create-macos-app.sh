#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Classic Player - Build ClassicPlayer.app for macOS
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ClassicPlayer-macOS/ClassicPlayer.app"

echo "Creating ClassicPlayer.app..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>classicplayer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.classicplayer</string>
    <key>CFBundleName</key>
    <string>Classic Player</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cat > "$APP_DIR/Contents/MacOS/classicplayer" << 'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$DIR/Resources/portable_config"

if [ -x "$DIR/MacOS/mpv" ]; then
    MPV="$DIR/MacOS/mpv"
elif command -v mpv >/dev/null 2>&1; then
    MPV="$(command -v mpv)"
elif [ -x "/opt/homebrew/bin/mpv" ]; then
    MPV="/opt/homebrew/bin/mpv"
elif [ -x "/usr/local/bin/mpv" ]; then
    MPV="/usr/local/bin/mpv"
else
    osascript -e 'display alert "Classic Player" message "mpv engine was not found.\n\nPlease install mpv via Homebrew:\nbrew install mpv" as critical'
    exit 1
fi

exec "$MPV" --config-dir="$CONFIG_DIR" "$@"
EOF

chmod +x "$APP_DIR/Contents/MacOS/classicplayer"

echo "Copying configuration to App Resources..."
rm -rf "$APP_DIR/Contents/Resources/portable_config"
cp -R "$ROOT_DIR/src/portable_config" "$APP_DIR/Contents/Resources/portable_config"

echo "ClassicPlayer.app built successfully at: $APP_DIR"
