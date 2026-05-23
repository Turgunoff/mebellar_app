#!/usr/bin/env bash
# Build a production Android App Bundle the right way: with env vars
# baked in, code obfuscated, and debug symbols saved for stack-trace
# decoding. Running `flutter build appbundle --release` directly is the
# #1 way to ship a "splash never appears" build — the env stays empty
# and `AppConfig.assertConfigured` aborts boot before any UI mounts.
#
# Usage:  ./tools/build_release.sh
# Output: build/app/outputs/bundle/release/app-release.aab
#         build/symbols/                           (upload to crash service)

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f env/prod.json ]; then
  echo "✗ env/prod.json not found — create it from env/example.json" >&2
  exit 1
fi

echo "→ Cleaning previous build…"
flutter clean

echo "→ Restoring pub packages…"
flutter pub get

echo "→ Building release AAB with prod env…"
flutter build appbundle --release \
  --dart-define-from-file=env/prod.json \
  --obfuscate \
  --split-debug-info=build/symbols

echo
echo "✓ Build complete:"
echo "  AAB:     build/app/outputs/bundle/release/app-release.aab"
echo "  Symbols: build/symbols/   (upload to Sentry / Play Console)"
