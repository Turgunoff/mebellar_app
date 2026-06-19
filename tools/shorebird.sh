#!/usr/bin/env bash
# Shorebird code-push wrapper for woody_app — release, patch, and a
# pre-patch change classifier ("what did I change, and can I patch it?").
#
# WHY this lives next to build_release.sh:
#   • A store build that can later receive code-push patches MUST be built
#     with `shorebird release`, not `flutter build`. The plain flutter
#     artifacts from build_release.sh are NOT patchable — upload a
#     `shorebird release` build when you want hot-fix patches.
#   • `shorebird patch` only ships *Dart* code. Native changes (android/,
#     ios/), bundled assets (assets/), and dependency changes need a brand
#     new release. Shorebird's own CLI refuses these diffs
#     (--allow-native-diffs / --allow-asset-diffs warn they crash the app),
#     so `check`/`patch` here classify your working tree the same way and
#     stop you before you ship a broken patch.
#
# The release ledger (tools/shorebird/releases.log) records version → git
# SHA for every release, so `check`/`patch` can diff today's tree against
# the exact source that shipped — your "which files did I touch since
# 1.0.x?" memory, the thing that's easy to forget.
#
# Usage:
#   ./tools/shorebird.sh check  [<base-ref>]                      # classify changes, no build
#   ./tools/shorebird.sh release [android|ios|all] [--note "…"]   # build + log to ledger
#   ./tools/shorebird.sh patch   [android|ios|all] [--release-version X] [--note "…"] [--force]
#   ./tools/shorebird.sh record  <version> [--note "…"]           # log a release built elsewhere
#   ./tools/shorebird.sh log                                      # print the ledger
#
# `all` / no target = Android only (iOS needs a Mac + signing — run `ios`).
# Bump `version:` in pubspec.yaml before each new release (stores reject a
# duplicate build number; Shorebird keys patches off the release version).

set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="env/prod.json"
SYMBOLS_DIR="build/symbols"
LEDGER="tools/shorebird/releases.md"  # .md, not .log — *.log is gitignored

# ── shorebird on PATH ─────────────────────────────────────────────────────
# The installer adds ~/.shorebird/bin to interactive shells; a script may not
# inherit it.
if ! command -v shorebird >/dev/null 2>&1; then
  export PATH="$HOME/.shorebird/bin:$PATH"
fi
if ! command -v shorebird >/dev/null 2>&1; then
  echo "✗ shorebird CLI topilmadi. O'rnating: https://docs.shorebird.dev" >&2
  exit 1
fi

# ── helpers ───────────────────────────────────────────────────────────────
pubspec_version() {
  grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}'
}

# Latest SHA recorded in the ledger (optionally for a given version string).
# Parses the markdown table rows: | Sana | Versiya | Git SHA | Platforma | Izoh |
ledger_sha() {
  local want="${1:-}"
  [ -f "$LEDGER" ] || return 0
  awk -F'|' -v want="$want" '
    /^[[:space:]]*\|/ {                       # only table rows start with |
      ver = $3; sha = $4
      gsub(/^[ \t]+|[ \t]+$/, "", ver)
      gsub(/^[ \t]+|[ \t]+$/, "", sha)
      if (ver == "Versiya" || ver ~ /^-+$/ || ver == "") next   # header + separator
      if (want == "" || ver == want) last = sha
    }
    END { if (last != "") print last }
  ' "$LEDGER"
}

require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "✗ $ENV_FILE topilmadi — env/example.json'dan nusxa oling." >&2
    exit 1
  fi
  local key val
  for key in WOODY_API_URL YANDEX_GEOCODER_API_KEY; do
    val="$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$ENV_FILE" | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
    if [ -z "$val" ]; then
      echo "✗ $ENV_FILE: \"$key\" bo'sh — ilova bootда yiqiladi." >&2
      exit 1
    fi
  done
}

# ── change classifier ─────────────────────────────────────────────────────
# Splits files changed since <base> into: Dart (patchable), native / asset /
# deps / flutter-version (each needs a new release), and ignored (doesn't
# ship). Sets globals: PATCH_BLOCKED (0/1) and BLOCK_KIND (hard|soft|"").
classify_changes() {
  local base="$1"

  if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
    echo "✗ '$base' — yaroqli git commit emas." >&2
    exit 1
  fi

  local dart="" native="" asset="" deps="" flutter="" ignored=""
  local n_dart=0 n_native=0 n_asset=0 n_deps=0 n_flutter=0

  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      test/*|integration_test/*)
        ignored="${ignored}${f}"$'\n' ;;
      android/*|ios/*|macos/*|linux/*|windows/*|web/*)
        native="${native}${f}"$'\n'; n_native=$((n_native+1)) ;;
      assets/*)
        asset="${asset}${f}"$'\n'; n_asset=$((n_asset+1)) ;;
      pubspec.yaml|pubspec.lock)
        deps="${deps}${f}"$'\n'; n_deps=$((n_deps+1)) ;;
      .metadata)
        flutter="${flutter}${f}"$'\n'; n_flutter=$((n_flutter+1)) ;;
      lib/*|*.dart)
        dart="${dart}${f}"$'\n'; n_dart=$((n_dart+1)) ;;
      tools/*|docs/*|.github/*|.claude/*|.vscode/*|.history/*|screenshots/*|\
      env/*|*.md|*.png|*.jpg|*.jpeg|analysis_options.yaml|dart_test.yaml|\
      .gitignore|firebase.json|flutter_native_splash.yaml|shorebird.yaml|\
      .metadata.bak)
        ignored="${ignored}${f}"$'\n' ;;
      *)
        # Unknown path — surface it as "review" rather than silently ignore.
        deps="${deps}${f}  (noma'lum — tekshiring)"$'\n'; n_deps=$((n_deps+1)) ;;
    esac
  done < <( { git diff --name-only "$base" --; git ls-files --others --exclude-standard; } | sort -u )

  local hard=$((n_native + n_asset + n_flutter))
  local total=$((hard + n_deps + n_dart))

  echo "  Taqqoslash bazasi: $base  ($(git rev-parse --short "$base"))"
  echo "  Joriy holat:       working tree ($(pubspec_version))"
  echo

  if [ "$total" -eq 0 ]; then
    echo "ℹ️  Hech qanday o'zgarish yo'q."
    PATCH_BLOCKED=0; BLOCK_KIND=""
    return
  fi

  if [ "$n_dart" -gt 0 ]; then
    echo "✅  Dart kodi (patch'ga tushadi) — $n_dart ta:"
    printf '%s' "$dart" | sed 's/^/      • /'
    echo
  fi
  if [ "$n_native" -gt 0 ]; then
    echo "⛔️  Native kod (android/ios) — $n_native ta → YANGI RELEASE kerak:"
    printf '%s' "$native" | sed 's/^/      • /'
    echo
  fi
  if [ "$n_asset" -gt 0 ]; then
    echo "⛔️  Asset'lar (binaryga bog'langan) — $n_asset ta → YANGI RELEASE kerak:"
    printf '%s' "$asset" | sed 's/^/      • /'
    echo
  fi
  if [ "$n_flutter" -gt 0 ]; then
    echo "⛔️  Flutter versiyasi (.metadata) → YANGI RELEASE kerak:"
    printf '%s' "$flutter" | sed 's/^/      • /'
    echo
  fi
  if [ "$n_deps" -gt 0 ]; then
    echo "⚠️  Bog'liqliklar / noma'lum — $n_deps ta → tekshiring:"
    echo "      (pubspec o'zgarsa: sof-Dart paket patch'ga tushadi, native plugin"
    echo "       qo'shilsa YANGI RELEASE kerak)"
    printf '%s' "$deps" | sed 's/^/      • /'
    echo
  fi

  echo "──────────────────────────────────────────────────────────────"
  if [ "$hard" -gt 0 ]; then
    echo "❌  PATCH QILIB BO'LMAYDI — native/asset/flutter o'zgarishlari bor."
    echo "    Yangi 'shorebird release' chiqaring va do'konga yuklang."
    PATCH_BLOCKED=1; BLOCK_KIND="hard"
  elif [ "$n_deps" -gt 0 ]; then
    echo "⚠️  EHTIYOT — pubspec/noma'lum fayl o'zgargan. Agar yangi native"
    echo "    plugin qo'shilmagan bo'lsa patch ishlaydi; aks holda release kerak."
    PATCH_BLOCKED=1; BLOCK_KIND="soft"
  else
    echo "✅  PATCH MUMKIN — faqat Dart kodi o'zgargan, xatosiz tushadi."
    PATCH_BLOCKED=0; BLOCK_KIND=""
  fi
  echo "──────────────────────────────────────────────────────────────"
}

# ── ledger ────────────────────────────────────────────────────────────────
record_release() {
  local version="$1" platforms="$2" note="${3:-—}"
  local sha date
  sha="$(git rev-parse --short=12 HEAD)"
  date="$(git show -s --format=%cd --date=short HEAD)"  # commit date — no wall clock needed
  mkdir -p "$(dirname "$LEDGER")"
  if [ ! -f "$LEDGER" ]; then
    {
      echo "# Shorebird release ledger"
      echo
      echo "\`tools/shorebird.sh check\` shu jadvaldagi Git SHA'ga nisbatan diff oladi."
      echo
      echo "| Sana | Versiya | Git SHA | Platforma | Izoh |"
      echo "|------|---------|---------|-----------|------|"
    } > "$LEDGER"
  fi
  echo "| ${date} | ${version} | ${sha} | ${platforms} | ${note} |" >> "$LEDGER"
  echo "→ Ledger'ga yozildi: $version @ $sha  ($LEDGER)"
}

warn_if_dirty() {
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "⚠️  Ishchi daraxt 'dirty' (commit qilinmagan o'zgarishlar bor)." >&2
    echo "    Ledger HEAD commit'ini yozadi — keyingi 'check' aniq bo'lishi uchun" >&2
    echo "    release'ni toza (commit qilingan) holatdan chiqargan ma'qul." >&2
    echo >&2
  fi
}

# ── arg parse ─────────────────────────────────────────────────────────────
CMD="${1:-help}"; shift || true

TARGET="all"
NOTE=""
RELEASE_VERSION=""
FORCE=0
BASE_REF=""
REC_VERSION=""

while [ $# -gt 0 ]; do
  case "$1" in
    android|ios|all)     TARGET="$1" ;;
    --note)              NOTE="${2:-}"; shift ;;
    --release-version)   RELEASE_VERSION="${2:-}"; shift ;;
    --force)             FORCE=1 ;;
    *)
      # First positional after `check`/`record` is the base-ref / version.
      if [ "$CMD" = "check" ] && [ -z "$BASE_REF" ]; then BASE_REF="$1"
      elif [ "$CMD" = "record" ] && [ -z "$REC_VERSION" ]; then REC_VERSION="$1"
      else echo "✗ noma'lum argument: $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

# Resolve platform list (all = Android only, like build_release.sh).
case "$TARGET" in
  android|all) PLATFORM="android" ;;
  ios)         PLATFORM="ios" ;;
esac

FLUTTER_ARGS=(
  --dart-define-from-file="$ENV_FILE"
  --obfuscate
  --split-debug-info="$SYMBOLS_DIR"
)

# ── commands ──────────────────────────────────────────────────────────────
case "$CMD" in
  check)
    if [ -z "$BASE_REF" ]; then
      BASE_REF="$(ledger_sha "")"
      if [ -z "$BASE_REF" ]; then
        echo "ℹ️  Hali hech qanday release ledger'da yo'q."
        echo "    Avval 'tools/shorebird.sh release' bilan release chiqaring,"
        echo "    yoki taqqoslash uchun git ref bering: 'tools/shorebird.sh check <tag|sha>'."
        exit 0
      fi
    fi
    echo "→ O'zgarishlarni tahlil qilmoqda…"
    echo
    classify_changes "$BASE_REF"
    ;;

  release)
    [ "$PLATFORM" = "ios" ] && [ "$(uname)" != "Darwin" ] && {
      echo "✗ iOS release faqat macOS + Xcode'da." >&2; exit 1; }
    [ "$PLATFORM" = "android" ] && [ ! -f android/key.properties ] && {
      echo "✗ android/key.properties yo'q — release debug kalit bilan imzolanadi." >&2; exit 1; }
    require_env
    warn_if_dirty
    local_version="$(pubspec_version)"
    echo "→ Shorebird release  $local_version  ($PLATFORM)"
    echo "  env: $ENV_FILE"
    echo
    shorebird release "$PLATFORM" -- "${FLUTTER_ARGS[@]}"
    echo
    record_release "$local_version" "$PLATFORM" "$NOTE"
    echo "✓ Release tayyor. Do'konga shorebird chiqargan artifaktni yuklang."
    ;;

  patch)
    [ "$PLATFORM" = "ios" ] && [ "$(uname)" != "Darwin" ] && {
      echo "✗ iOS patch faqat macOS'da." >&2; exit 1; }
    require_env
    [ -z "$RELEASE_VERSION" ] && RELEASE_VERSION="$(pubspec_version)"

    # Preflight: classify against the recorded release before building.
    base="$(ledger_sha "$RELEASE_VERSION")"; [ -z "$base" ] && base="$(ledger_sha "")"
    if [ -n "$base" ]; then
      echo "→ Patch preflight (release $RELEASE_VERSION):"
      echo
      classify_changes "$base"
      echo
      if [ "$PATCH_BLOCKED" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
        echo "✗ To'xtatildi — yuqoridagi bloklovchi o'zgarishlar bor." >&2
        echo "  Baribir davom etish uchun: --force (tavsiya etilmaydi)." >&2
        exit 1
      fi
    else
      echo "⚠️  Ledger'da '$RELEASE_VERSION' uchun yozuv yo'q — preflight o'tkazib"
      echo "    yuborildi. Shorebird o'zi native/asset diff'ni tekshiradi."
      echo
    fi

    echo "→ Shorebird patch  release-version=$RELEASE_VERSION  ($PLATFORM)"
    shorebird patch -p "$PLATFORM" --release-version "$RELEASE_VERSION" -- "${FLUTTER_ARGS[@]}"
    echo "✓ Patch yuborildi."
    ;;

  record)
    [ -z "$REC_VERSION" ] && { echo "✗ versiya bering: tools/shorebird.sh record 1.0.18+18" >&2; exit 2; }
    warn_if_dirty
    record_release "$REC_VERSION" "${TARGET}" "$NOTE"
    ;;

  log)
    if [ -f "$LEDGER" ]; then cat "$LEDGER"; else echo "ℹ️  Ledger hali bo'sh ($LEDGER)."; fi
    ;;

  help|-h|--help)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    echo "✗ noma'lum buyruq: $CMD  (check | release | patch | record | log | help)" >&2
    exit 2
    ;;
esac
