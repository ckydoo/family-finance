#!/usr/bin/env bash
# Mhuri Money — sandbox Flutter toolchain setup.
# Idempotent: safe to run every turn; skips work already done.
# Usage: bash mhuri-money/tools/setup_flutter.sh
set -e

SDK=/home/user/build/flutter-sdk

if [ -x "$SDK/bin/flutter" ]; then
  echo "[setup] Flutter SDK already present: $("$SDK/bin/flutter" --version 2>&1 | head -1)"
else
  echo "[setup] installing Flutter SDK..."
  mkdir -p /home/user/build
  cd /home/user/build
  VER=$(python3 -c "
import json,urllib.request
d=json.load(urllib.request.urlopen('https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json'))
h=d['current_release']['stable']
print([r['archive'] for r in d['releases'] if r['hash']==h][0])")
  echo "[setup] latest stable: $VER"
  curl -sSL -o flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/$VER"
  tar -xJf flutter.tar.xz
  rm -f flutter.tar.xz
  git config --global --add safe.directory "$SDK" 2>/dev/null || true
  echo "[setup] installed: $("$SDK/bin/flutter" --version 2>&1 | head -1)"
fi

export PATH="$SDK/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true

cd /home/user/mhuri-money/app
flutter pub get 1>/dev/null
echo "[setup] pub get OK — ready to analyze/test:"
echo "  export PATH=$SDK/bin:\$PATH"
echo "  cd /home/user/mhuri-money/app && flutter analyze && flutter test"
