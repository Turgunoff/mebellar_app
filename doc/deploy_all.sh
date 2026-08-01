#!/usr/bin/env bash
#
# deploy_all.sh — commit + push the three Woody repos to `main`, then ship a
# Dart-only ANDROID Shorebird OTA patch. iOS is intentionally NOT patched.
#
# ⚠️  CONSEQUENCES (this script is outward-facing and hard to reverse):
#   • Pushing woody_backend / woody_admin to `main` triggers their PRODUCTION
#     GitHub Actions deploys (api.woody.uz / admin.woody.uz).
#       → after the backend deploy, run the achievements seed once:
#           woody migrate && woody seed-achievements
#   • The Shorebird step ships a LIVE OTA patch to Android users.
#   • `git add -A` stages EVERYTHING currently uncommitted in each repo — it may
#     bundle more than the achievements work. Review `git status` first.
#
# Usage:  ./deploy_all.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS=("woody_backend" "woody_admin" "mebellar_app")
COMMIT_MSG="feat(achievements): implement customer shop profile trust badges and optimize layout"
# Per the project's commit convention (AI-assisted change attribution).
COMMIT_TRAILER=$'\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>'

hr() { printf '════════════════════════════════════════════════════════════\n'; }

commit_and_push() {
  local repo="$1"
  local dir="$ROOT/$repo"

  echo ""; hr; echo "▶ $repo"; hr

  if [[ ! -d "$dir/.git" ]]; then
    echo "  ✗ $dir is not a git repository — skipping"
    return 1
  fi

  # Safety: only ever push the real main branch.
  local branch
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" ]]; then
    echo "  ✗ on branch '$branch', not 'main' — refusing to push."
    echo "    Checkout main in $repo and re-run."
    return 1
  fi

  echo "  Working tree:"
  git -C "$dir" status --short | sed 's/^/    /' || true

  # Stage everything, commit only when something is actually staged.
  git -C "$dir" add -A
  if git -C "$dir" diff --cached --quiet; then
    echo "  • nothing new to commit"
  else
    git -C "$dir" commit -m "${COMMIT_MSG}${COMMIT_TRAILER}"
    echo "  ✓ committed: $(git -C "$dir" rev-parse --short HEAD)"
  fi

  echo "  ↑ pushing origin main (triggers CI/CD)…"
  git -C "$dir" push origin main
  echo "  ✓ pushed"
}

# ── 1. Commit + push every repo ──────────────────────────────────────────────
for repo in "${REPOS[@]}"; do
  commit_and_push "$repo"
done

# ── 2. Android-only Shorebird OTA patch ──────────────────────────────────────
echo ""; hr
echo "▶ Shorebird patch — ANDROID ONLY (iOS deliberately skipped)"
hr
cd "$ROOT/mebellar_app"

if [[ -x tools/shorebird.sh ]]; then
  # Project wrapper: env + signing preflight, and patch-safety gate (aborts on
  # native/asset/Flutter diffs that would crash an OTA patch). Android target
  # only — iOS is never built here. The user's '--no-gcloud-logging' is not a
  # real shorebird flag; the wrapper is the repo's standard entrypoint.
  ./tools/shorebird.sh patch android
else
  echo "  (tools/shorebird.sh not found — falling back to raw CLI)"
  shorebird patch android
fi

echo ""; hr
echo "✓ Done. Android OTA patch shipped; iOS was NOT patched."
echo "  Reminder: on the backend host run  woody migrate && woody seed-achievements"
hr
