#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
ARCH="arm64"
APP_NAME="uPulls"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "→ Building $APP_NAME ($CONFIG, $ARCH)…"
swift build -c "$CONFIG" --arch "$ARCH"

BIN_PATH=".build/$ARCH-apple-macosx/$CONFIG/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build output missing: $BIN_PATH" >&2
    exit 1
fi

echo "→ Bundling into ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "→ Ad-hoc signing…"
codesign --force --deep --sign - "$APP" >/dev/null

echo "✔ Done: $APP"
echo
echo "Run:      open $APP"
echo "Install:  cp -R $APP /Applications/"
