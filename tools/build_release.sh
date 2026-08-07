#!/usr/bin/env bash
# Build production artifacts the right way: env vars baked in, Dart code
# obfuscated, and debug symbols saved for stack-trace decoding.
#
# Running `flutter build appbundle --release` (or `build ipa`) directly is
# the #1 way to ship a "splash never appears" build — the env stays empty
# and `AppConfig.assertConfigured` aborts boot before any UI mounts.
#
# Produces, depending on target:
#   • AAB           → Play Console upload (Google re-signs per-device splits)
#   • universal APK → sideload / QA / direct install (one APK, all ABIs)
#   • IPA           → App Store Connect / TestFlight upload  (macOS only)
#
# Usage:
#   ./tools/build_release.sh                   # AAB + universal APK (Android)
#   ./tools/build_release.sh aab               # AAB only
#   ./tools/build_release.sh apk               # universal APK only
#   ./tools/build_release.sh all               # AAB + APK (same as no arg)
#   ./tools/build_release.sh ipa               # signed IPA (App Store / TestFlight)
#   ./tools/build_release.sh ipa --no-codesign # unsigned .app (CI / quick check)
#   ./tools/build_release.sh --no-clean        # skip `flutter clean` (faster reruns)
#
# `all` is Android only — iOS needs code signing and a Mac, so build it
# explicitly with `ipa`. Bump `version:` in pubspec.yaml before each store
# upload (1.0.5+6 → 1.0.5+7): both Play and App Store reject a duplicate
# build number.
#
# ── Code push (Shorebird) ─────────────────────────────────────────────────
# These are PLAIN flutter builds — they CANNOT receive Shorebird patches.
# For a store build you can later hot-fix with `shorebird patch`, build it
# with `tools/shorebird.sh release` instead and upload THAT artifact. Then
# `tools/shorebird.sh check` tells you whether your changes are patch-safe
# (Dart only) or need a fresh release (native / assets / deps).

set -euo pipefail

cd "$(dirname "$0")/.."

# ── args ────────────────────────────────────────────────────────────────
WHAT="all"          # all | aab | apk | ipa
DO_CLEAN=1
NO_CODESIGN=0
for arg in "$@"; do
  case "$arg" in
    aab)           WHAT="aab" ;;
    apk)           WHAT="apk" ;;
    all)           WHAT="all" ;;
    ipa|ios)       WHAT="ipa" ;;
    --no-clean)    DO_CLEAN=0 ;;
    --no-codesign) NO_CODESIGN=1 ;;
    *) echo "✗ unknown arg: $arg  (expected: aab | apk | all | ipa | --no-clean | --no-codesign)" >&2; exit 2 ;;
  esac
done

# Which platform does the selected target touch?
WANTS_ANDROID=0
WANTS_IOS=0
case "$WHAT" in
  aab|apk|all) WANTS_ANDROID=1 ;;
  ipa)         WANTS_IOS=1 ;;
esac

ENV_FILE="env/prod.json"
SYMBOLS_DIR="build/symbols"

# ── preflight ───────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "✗ $ENV_FILE not found — create it from env/example.json" >&2
  exit 1
fi

# Android release must be signed with the upload key, not debug keys.
if [ "$WANTS_ANDROID" -eq 1 ] && [ ! -f android/key.properties ]; then
  echo "✗ android/key.properties not found — release would be signed with debug keys." >&2
  echo "  Create it (storeFile / storePassword / keyAlias / keyPassword)." >&2
  exit 1
fi

# IPA archiving is macOS-only (needs the Xcode toolchain). Catch it early.
if [ "$WANTS_IOS" -eq 1 ] && [ "$(uname)" != "Darwin" ]; then
  echo "✗ iOS builds require macOS + Xcode — current host is $(uname)." >&2
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

# Both stores reject a duplicate build number, and you only find out AFTER the
# upload — minutes of build time wasted. The Shorebird ledger is the one place
# that knows what already shipped, so check it here too. A warning, not a hard
# stop: this script also builds QA/sideload APKs where reusing a version is fine.
LEDGER="tools/shorebird/releases.md"
if [ -f "$LEDGER" ] && grep -qF "| ${VERSION} |" "$LEDGER"; then
  echo "⚠️  $VERSION allaqachon $LEDGER da qayd etilgan:" >&2
  grep -F "| ${VERSION} |" "$LEDGER" | sed 's/^/      /' >&2
  echo "    Do'kon yuklamasi uchun pubspec.yaml'da 'version:' ni oshiring." >&2
  echo >&2
fi

echo "→ Building woody_app  version $VERSION  (targets: $WHAT)"
echo "  env:     $ENV_FILE"
if [ "$WANTS_ANDROID" -eq 1 ]; then
  echo "  signing: android/key.properties"
fi
if [ "$WANTS_IOS" -eq 1 ] && [ "$NO_CODESIGN" -eq 1 ]; then
  echo "  signing: skipped (--no-codesign → unsigned .app, not an installable IPA)"
fi
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

if [ "$WHAT" = "ipa" ]; then
  echo
  if [ "$NO_CODESIGN" -eq 1 ]; then
    echo "→ Building unsigned iOS .app (obfuscated, prod env)…"
    flutter build ios --no-codesign "${COMMON_FLAGS[@]}"
  else
    echo "→ Building release IPA (obfuscated, prod env)…"
    flutter build ipa "${COMMON_FLAGS[@]}"
  fi
fi

# ── report ──────────────────────────────────────────────────────────────
echo
echo "✓ Build complete — version $VERSION"
echo

AAB="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"
IPA=""

if { [ "$WHAT" = "aab" ] || [ "$WHAT" = "all" ]; } && [ -f "$AAB" ]; then
  echo "  AAB:     $AAB   ($(du -h "$AAB" | cut -f1))"
fi
if { [ "$WHAT" = "apk" ] || [ "$WHAT" = "all" ]; } && [ -f "$APK" ]; then
  echo "  APK:     $APK   ($(du -h "$APK" | cut -f1))"
fi
if [ "$WHAT" = "ipa" ]; then
  if [ "$NO_CODESIGN" -eq 1 ]; then
    APP="$(find build/ios/iphoneos -maxdepth 1 -name '*.app' 2>/dev/null | head -1)"
    [ -n "$APP" ] && echo "  .app:    $APP   ($(du -sh "$APP" | cut -f1))   — unsigned, not installable"
  else
    IPA="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' 2>/dev/null | head -1)"
    [ -n "$IPA" ] && echo "  IPA:     $IPA   ($(du -h "$IPA" | cut -f1))"
  fi
fi
echo "  Symbols: $SYMBOLS_DIR/   (upload to crash service — do NOT commit)"
echo

if [ "$WANTS_ANDROID" -eq 1 ]; then
  echo "  Crashlytics auto-receives native (NDK) symbols via the Gradle"
  echo "  plugin. For obfuscated Dart stack traces, decode locally with:"
  echo "    flutter symbolize -i <crash.txt> -d $SYMBOLS_DIR/app.android-arm64.symbols"
fi
if [ "$WANTS_IOS" -eq 1 ] && [ "$NO_CODESIGN" -eq 0 ]; then
  echo "  Upload the IPA via Xcode Organizer, Transporter, or:"
  echo "    xcrun altool --upload-app -f \"${IPA:-<ipa>}\" -t ios --apiKey <KEY> --apiIssuer <ISSUER>"
  echo "  Decode obfuscated Dart stack traces with:"
  echo "    flutter symbolize -i <crash.txt> -d $SYMBOLS_DIR/app.ios-arm64.symbols"
fi

# Code-push reminder — a plain build can't be patched later.
if [ -f shorebird.yaml ]; then
  echo
  echo "  ℹ️  Bu oddiy flutter build — Shorebird patch QABUL QILMAYDI."
  echo "     Keyin patch qilinadigan release uchun: ./tools/shorebird.sh release"
fi
