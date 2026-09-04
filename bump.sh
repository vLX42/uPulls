#!/usr/bin/env bash
#
# Bump the app version across every file that references it.
# Usage:  ./bump.sh 1.2.0
#
set -euo pipefail
cd "$(dirname "$0")"

NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new-version>" >&2
    echo "Example: $0 1.2.0" >&2
    exit 1
fi

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must look like X.Y.Z (got '$NEW_VERSION')" >&2
    exit 1
fi

CURRENT_VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
CURRENT_BUILD="$(plutil -extract CFBundleVersion raw Resources/Info.plist)"

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
    echo "Already at version $NEW_VERSION; nothing to do."
    exit 0
fi

NEW_BUILD=$((CURRENT_BUILD + 1))

echo "→ $CURRENT_VERSION (build $CURRENT_BUILD)  →  $NEW_VERSION (build $NEW_BUILD)"

# Info.plist
plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" Resources/Info.plist
plutil -replace CFBundleVersion -string "$NEW_BUILD" Resources/Info.plist
echo "  ✔ Resources/Info.plist"

# release.sh default
sed -i '' "s|VERSION=\"\${VERSION:-${CURRENT_VERSION}}\"|VERSION=\"\${VERSION:-${NEW_VERSION}}\"|" release.sh
echo "  ✔ release.sh"

# website/index.html — release-URL path and the visible version chip
sed -i '' \
    -e "s|v${CURRENT_VERSION}/uPulls-${CURRENT_VERSION}.zip|v${NEW_VERSION}/uPulls-${NEW_VERSION}.zip|g" \
    -e "s|>v${CURRENT_VERSION}<|>v${NEW_VERSION}<|g" \
    website/index.html
echo "  ✔ website/index.html"

# README.md — the release.sh comment
sed -i '' "s|dist/uPulls-${CURRENT_VERSION}.zip|dist/uPulls-${NEW_VERSION}.zip|g" README.md
echo "  ✔ README.md"

echo
echo "✔ Bumped to $NEW_VERSION. Next:"
echo "    git diff                                    # eyeball the changes"
echo "    git commit -am \"Bump version to $NEW_VERSION\""
echo "    git tag v$NEW_VERSION && git push origin main v$NEW_VERSION"
echo "    ./deploy-site.sh                            # once the release is published"
