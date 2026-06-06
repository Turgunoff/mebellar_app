#!/usr/bin/env bash
# Build production Android artifacts the right way: env vars baked in,
# Dart code obfuscated, and debug symbols saved for stack-trace decoding.
#
# Running `flutter build appbundle --release` directly is the #1 way to
# ship a "splash never appears" build — the env stays empty and
# `AppConfig.assertConfigured` aborts boot before any UI mounts.
#
# Produces BOTH:
#   • AAB           → Play Console upload (Google re-signs per-device splits)
#   • universal APK → sideload / QA / direct install (one APK, all ABIs)
#
# Usage:
#   ./tools/build_release.sh            # AAB + universal APK (default)
#   ./tools/build_release.sh aab        # AAB only
#   ./tools/build_release.sh apk        # universal APK only
#   ./tools/build_release.sh --no-clean # skip `flutter clean` (faster reruns)
#
# Bump `version:` in pubspec.yaml before each Play Console upload
# (1.0.5+6 → 1.0.5+7). Play rejects a duplicate versionCode.

set -euo pipefail

cd "$(dirname "$0")/.."

# ── args ────────────────────────────────────────────────────────────────
WHAT="all"          # all | aab | apk
DO_CLEAN=1
for arg in "$@"; do
  case "$arg" in
    aab)        WHAT="aab" ;;
    apk)        WHAT="apk" ;;
    all)        WHAT="all" ;;
    --no-clean) DO_CLEAN=0 ;;
    *) echo "✗ unknown arg: $arg  (expected: aab | apk | all | --no-clean)" >&2; exit 2 ;;
  esac
done

ENV_FILE="env/prod.json"
SYMBOLS_DIR="build/symbols"

# ── preflight ───────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "✗ $ENV_FILE not found — create it from env/example.json" >&2
  exit 1
fi

if [ ! -f android/key.properties ]; then
  echo "✗ android/key.properties not found — release would be signed with debug keys." >&2
  echo "  Create it (storeFile / storePassword / keyAlias / keyPassword)." >&2
  exit 1
fi

# Fail loudly if a required env key is blank — same contract as
# AppConfig.assertConfigured(), but before we burn 5 minutes on a build.
for key in WOODY_API_URL YANDEX_GEOCODER_API_KEY; do
  val="$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$ENV_FILE" | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
  if [ -z "$val" ]; then
    echo "✗ $ENV_FILE: \"$key\" is empty — the app crashes at boot without it." >&2
    exit 1
  fi
done

VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
echo "→ Building woody_app  version $VERSION  (targets: $WHAT)"
echo "  env:     $ENV_FILE"
echo "  signing: android/key.properties"
echo

# ── build ───────────────────────────────────────────────────────────────
if [ "$DO_CLEAN" -eq 1 ]; then
  echo "→ Cleaning previous build…"
  flutter clean
fi

echo "→ Restoring pub packages…"
flutter pub get

COMMON_FLAGS=(
  --release
  --dart-define-from-file="$ENV_FILE"
  --obfuscate
  --split-debug-info="$SYMBOLS_DIR"
)

if [ "$WHAT" = "aab" ] || [ "$WHAT" = "all" ]; then
  echo
  echo "→ Building release AAB (obfuscated, prod env)…"
  flutter build appbundle "${COMMON_FLAGS[@]}"
fi

if [ "$WHAT" = "apk" ] || [ "$WHAT" = "all" ]; then
  echo
  echo "→ Building universal release APK (obfuscated, prod env)…"
  flutter build apk "${COMMON_FLAGS[@]}"
fi

# ── report ──────────────────────────────────────────────────────────────
echo
echo "✓ Build complete — version $VERSION"
echo

AAB="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"

if { [ "$WHAT" = "aab" ] || [ "$WHAT" = "all" ]; } && [ -f "$AAB" ]; then
  echo "  AAB:     $AAB   ($(du -h "$AAB" | cut -f1))"
fi
if { [ "$WHAT" = "apk" ] || [ "$WHAT" = "all" ]; } && [ -f "$APK" ]; then
  echo "  APK:     $APK   ($(du -h "$APK" | cut -f1))"
fi
echo "  Symbols: $SYMBOLS_DIR/   (upload to crash service — do NOT commit)"
echo
echo "  Crashlytics auto-receives native (NDK) symbols via the Gradle"
echo "  plugin. For obfuscated Dart stack traces, decode locally with:"
echo "    flutter symbolize -i <crash.txt> -d $SYMBOLS_DIR/app.android-arm64.symbols"
