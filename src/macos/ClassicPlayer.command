#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Classic Player - macOS Portable Runner
# Double-click this script in Finder or run from Terminal.
# ---------------------------------------------------------------------------
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DIR/portable_config"

# Locate mpv binary:
# 1. Bundled alongside this script
# 2. Installed via Homebrew (Apple Silicon: /opt/homebrew/bin/mpv, Intel: /usr/local/bin/mpv)
# 3. In system PATH
# 4. Inside standard MacPorts or /Applications/mpv.app
if [ -x "$DIR/bin/mpv" ]; then
    MPV="$DIR/bin/mpv"
elif [ -x "$DIR/mpv" ]; then
    MPV="$DIR/mpv"
elif command -v mpv >/dev/null 2>&1; then
    MPV="$(command -v mpv)"
elif [ -x "/opt/homebrew/bin/mpv" ]; then
    MPV="/opt/homebrew/bin/mpv"
elif [ -x "/usr/local/bin/mpv" ]; then
    MPV="/usr/local/bin/mpv"
elif [ -x "/opt/local/bin/mpv" ]; then
    MPV="/opt/local/bin/mpv"
elif [ -x "/Applications/mpv.app/Contents/MacOS/mpv" ]; then
    MPV="/Applications/mpv.app/Contents/MacOS/mpv"
else
    echo "=========================================================="
    echo "  Classic Player - mpv engine not found!"
    echo "=========================================================="
    echo "To run Classic Player on macOS, install mpv using Homebrew:"
    echo "    brew install mpv"
    echo ""
    echo "Or drop the 'mpv' binary into this folder."
    echo "=========================================================="
    if command -v osascript >/dev/null 2>&1; then
        osascript -e 'display alert "Classic Player" message "mpv engine was not found.\n\nPlease install mpv via Homebrew:\nbrew install mpv\n\nor place the mpv binary in this folder." as critical'
    fi
    exit 1
fi

exec "$MPV" --config-dir="$CONFIG_DIR" "$@"
