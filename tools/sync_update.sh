#!/usr/bin/env bash
# Overlay a sandbox download onto your git clone, then show the diff.
# Usage: ./tools/sync_update.sh <path-to-mhuri-money.zip-or-folder>
set -euo pipefail

SRC="${1:?usage: sync_update.sh <zip-or-folder>}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=""

if [ -d "$SRC" ]; then
  FROM="$SRC"
elif [ -f "$SRC" ]; then
  TMP="$(mktemp -d)"
  unzip -q "$SRC" -d "$TMP"
  FROM="$(find "$TMP" -maxdepth 2 -type d -name 'mhuri-money' | head -1)"
  [ -z "$FROM" ] && FROM="$TMP"
else
  echo "not a file or folder: $SRC" >&2; exit 1
fi

echo "Syncing $FROM → $REPO"
# copy everything except secrets and git internals
rsync -a --exclude '.git/' --exclude '.env' --exclude '.env.*' \
      --exclude 'node_modules/' --exclude 'build/' --exclude '.dart_tool/' \
      "$FROM"/ "$REPO"/

# restore the example file if the download lacks it
[ -f "$REPO/app/.env.example" ] || [ -f "$FROM/app/.env.example" ] || true

[ -n "$TMP" ] && rm -rf "$TMP"

cd "$REPO"
echo
echo "── git status ──────────────────────────────"
git status --short
echo
echo "Review with:  git diff   |   commit:  git add -A && git commit -m 'Sync from sandbox'"
