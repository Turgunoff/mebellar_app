#!/usr/bin/env bash
# Auto-format a Dart file after Claude edits or creates it.
#
# Wired as a PostToolUse hook on Edit + Write tools in
# `.claude/settings.json`. Claude Code passes the tool call payload as
# JSON on stdin — we parse it to find the file path, then format only
# that file (much faster than `dart format .`).
#
# Stays quiet on success; only echoes diagnostics on failure so the
# hook output doesn't clutter the conversation. Exit 0 unconditionally
# — a formatter failure should never block the edit itself.

set -uo pipefail

# Read the hook payload from stdin. Claude Code sends a JSON object
# with at least `tool_input.file_path` for Edit/Write.
payload=$(cat)

file=$(printf '%s' "$payload" \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null)

# No file path → nothing to format. Quiet exit.
if [ -z "$file" ]; then
  exit 0
fi

# Only format Dart files.
case "$file" in
  *.dart) ;;
  *) exit 0 ;;
esac

# Skip generated files (`.g.dart`, `.freezed.dart`) — they're produced
# by build_runner and overwriting them invalidates the next codegen.
case "$file" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.mocks.dart) exit 0 ;;
esac

# File might have been deleted in the same turn — skip if gone.
[ -f "$file" ] || exit 0

if ! command -v dart >/dev/null 2>&1; then
  # No `dart` on PATH — likely a CI container without Flutter SDK.
  # Don't fail the hook, just bow out.
  exit 0
fi

# `--set-exit-if-changed` returns non-zero when reformatting was needed
# (i.e. the file was already well-formatted) — we DON'T use it because
# we want format-on-edit to be a silent fixup, not a status report.
dart format "$file" >/dev/null 2>&1 || \
  echo "dart-format: failed on $file" >&2

exit 0
