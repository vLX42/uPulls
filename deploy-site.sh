#!/usr/bin/env bash
#
# Pushes website/index.html to the public companion repo that hosts the
# GitHub Pages homepage. The main repo stays private; only the site is
# public.
#
set -euo pipefail

cd "$(dirname "$0")"
SRC_DIR="$(pwd)"
SITE_REPO="vLX42/upulls-site"
SRC_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

TMP_DIR="$(mktemp -d -t upulls-site.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "→ Cloning $SITE_REPO"
gh repo clone "$SITE_REPO" "$TMP_DIR/site" >/dev/null

cp "$SRC_DIR"/website/* "$TMP_DIR/site/"

cd "$TMP_DIR/site"

if git diff --quiet && [ -z "$(git status --porcelain)" ]; then
    echo "✔ No changes to homepage; nothing to deploy."
    exit 0
fi

git add -A
git commit -m "Update homepage from uPulls@$SRC_SHA"
git push origin main

echo
echo "✔ Deployed."
echo "   https://vlx42.github.io/upulls-site/"
