#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-1.3.2}"
APP_NAME="uPulls"
DIST="dist"
STAGE="$DIST/staging"
ARCHIVE="$APP_NAME-$VERSION.zip"

echo "→ Building release v$VERSION"
./build.sh

echo "→ Staging release contents"
rm -rf "$DIST"
mkdir -p "$STAGE"
cp -R "build/$APP_NAME.app" "$STAGE/$APP_NAME.app"
cp INSTALL.txt "$STAGE/INSTALL.txt"

echo "→ Creating $ARCHIVE"
(cd "$STAGE" && ditto -c -k --sequesterRsrc --keepParent . "../$ARCHIVE")
rm -rf "$STAGE"

SHA=$(shasum -a 256 "$DIST/$ARCHIVE" | awk '{print $1}')
SIZE=$(du -h "$DIST/$ARCHIVE" | cut -f1)

cat > "$DIST/RELEASE_NOTES.md" <<EOF
# $APP_NAME v$VERSION

Open GitHub pull requests in your menu bar. Native, tiny, Apple Silicon.

## Download

\`$ARCHIVE\` ($SIZE)
SHA-256: \`$SHA\`

## Install

1. Unzip and drag \`$APP_NAME.app\` to \`/Applications\`.
2. Bypass Gatekeeper (this build isn't notarized):
   \`\`\`sh
   xattr -d com.apple.quarantine /Applications/$APP_NAME.app
   \`\`\`
   Or right-click → Open → confirm.
3. Click the pull-request icon in your menu bar.

See \`INSTALL.txt\` inside the zip for full details.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon

EOF

echo
echo "✔ Release ready:"
echo "    $DIST/$ARCHIVE   ($SIZE)"
echo "    sha256: $SHA"
echo "    notes:  $DIST/RELEASE_NOTES.md"
echo
echo "Upload $DIST/$ARCHIVE to a GitHub Release (or any static host)."
