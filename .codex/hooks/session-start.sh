#!/bin/bash
# SessionStart hook — provisions the Flutter SDK so `dart analyze` and
# `flutter test` work in Claude Code on the web sessions.
#
# Synchronous + idempotent: a cached SDK at the pinned version is reused, so
# only the first session in a fresh container pays the download cost.
set -euo pipefail

# Local machines already have Flutter on PATH — only provision in the remote
# (Claude Code on the web) container.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Pinned for reproducibility. 3.44.1 ships Dart 3.12.1, which satisfies the
# pubspec's `sdk: ^3.11.5`. Bump both the app and this line together.
FLUTTER_VERSION="3.44.1"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

# All progress goes to stderr — SessionStart stdout is injected into the
# session as context, so we keep it clean.
log() { echo "[session-start] $*" >&2; }

# Make the SDK visible to this hook process and to every later session command.
export PATH="$FLUTTER_HOME/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

if [ -x "$FLUTTER_HOME/bin/flutter" ] && \
   "$FLUTTER_HOME/bin/flutter" --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION}"; then
  log "Flutter ${FLUTTER_VERSION} already present at ${FLUTTER_HOME} — skipping download"
else
  log "Installing Flutter ${FLUTTER_VERSION} -> ${FLUTTER_HOME}"
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tmp="$(mktemp -d)"
  curl -fsSL --retry 3 --retry-delay 2 -o "${tmp}/${ARCHIVE}" "$URL"
  tar -xJf "${tmp}/${ARCHIVE}" -C "$(dirname "$FLUTTER_HOME")"
  rm -rf "$tmp"
fi

# Running as root against a git checkout trips Flutter's "dubious ownership"
# guard; allowlist the SDK dir so `flutter`/`dart` don't refuse to run.
git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true

# Non-interactive: no analytics prompt, no first-run banner mid-command.
flutter --disable-analytics >/dev/null 2>&1 || true

log "Resolving pub dependencies (flutter pub get)"
( cd "${CLAUDE_PROJECT_DIR:-.}" && flutter pub get ) >&2

# Pre-warm the Linux host test engine (flutter_tester) so the first
# `flutter test` of the session runs offline instead of downloading. Skip the
# mobile/web/desktop-build toolchains — unit/widget tests don't need them.
log "Pre-caching Linux test artifacts"
flutter precache --universal --linux \
  --no-android --no-ios --no-web --no-windows --no-macos --no-fuchsia >&2 || true

log "Flutter ready: $(flutter --version 2>/dev/null | head -1)"
