#!/usr/bin/env bash
# One command: overlay the sandbox download onto your clone, commit, push.
# Usage: ./tools/push_update.sh <path-to-mhuri-money.zip-or-folder> [message]
set -euo pipefail
SRC="${1:?usage: push_update.sh <zip-or-folder> [message]}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MSG="${2:-}"
TMP=""
if [ -d "$SRC" ]; then FROM="$SRC"
elif [ -f "$SRC" ]; then
  TMP="$(mktemp -d)"; unzip -q "$SRC" -d "$TMP"
  F="$(find "$TMP" -maxdepth 2 -type d -name 'mhuri-money' | head -1)"
  FROM="${F:-$TMP}"
else echo "not a file or folder: $SRC" >&2; exit 1; fi
cd "$REPO"
# portable overlay (no rsync dependency): copy all except git internals & secrets
(cd "$FROM" && tar cf - \
  --exclude='./.git' --exclude='./.env' --exclude='./.env.*' \
  --exclude='./RELEASE_NOTE.md' --exclude='./app/.env' \
  --exclude='*/build' --exclude='*/.dart_tool' --exclude='*/node_modules' \
  .) | tar xf - -C "$REPO"
[ -n "$TMP" ] && rm -rf "$TMP"
[ -f RELEASE_NOTE.md ] && MSG="$(head -1 RELEASE_NOTE.md)"
git add -A
if git diff --staged --quiet; then echo "Nothing new to commit."; exit 0; fi
git commit -m "${MSG:-Sync from sandbox}"
git push
echo "pushed"
