#!/usr/bin/env bash
#
# build_app_icons.sh — regenerate Woody's launcher + notification icons from the
# SVG masters in design/logo/.
#
# Unified brand mark: a WHITE cabinet glyph centered on a solid terracotta
# (#C27A5F) background — identical on Android and iOS, light and dark. There are
# deliberately NO iOS dark/tinted appearance variants (dropped for strict brand
# consistency) — the single "any appearance" set flutter_launcher_icons emits is
# the whole story now.
#
# Pipeline (default `all`):
#   1. sources       — rasterise the SVG masters to the 1024 PNG sources that
#                      flutter_launcher_icons consumes (foreground + monochrome
#                      land in both design/logo/ and assets/logo/; the full,
#                      terracotta-baked master becomes woody_logo_full.png).
#   2. flutter       — `dart run flutter_launcher_icons`: Android adaptive +
#                      monochrome (themed, A13+) and the iOS AppIcon set. Then we
#                      sweep any stale custom-format appearance PNGs from the
#                      appiconset (left over from the retired iOS-18 variants).
#   3. notification  — rasterise woody_notification.svg into the white-on-
#                      transparent ic_stat_woody.png status-bar icon at every
#                      Android density. Android draws only the alpha, so the
#                      silhouette must stay white-on-transparent.
#
# Usage:
#   tools/icons/build_app_icons.sh                # all three steps
#   tools/icons/build_app_icons.sh sources        # just refresh the PNG sources
#   tools/icons/build_app_icons.sh flutter        # just re-run FLI + iOS sweep
#   tools/icons/build_app_icons.sh notification   # just rebuild the status icon
#
# Requires: rsvg-convert (brew install librsvg) + python3 with Pillow.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DESIGN="$REPO_ROOT/design/logo"
ASSETS="$REPO_ROOT/assets/logo"
APPICON="$REPO_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES="$REPO_ROOT/android/app/src/main/res"

# Brand background (must match flutter_launcher_icons in pubspec + the SVGs +
# @color/ic_launcher_background). Terracotta = the CLAUDE.md brand accent.
TERRACOTTA="#C27A5F"

need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ missing dependency: $1" >&2; exit 1; }; }
need rsvg-convert
need python3

# render <svg> <out.png> [size]  — crisp square RGBA rasterisation (default 1024).
render() { local s="${3:-1024}"; rsvg-convert -w "$s" -h "$s" "$1" -o "$2"; }

# flatten <in.png> <out.png> <hex-bg>  — composite onto an opaque background and
# drop the alpha channel (App Store rejects an alpha channel on the icon).
flatten() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from PIL import Image
src, dst, hexbg = sys.argv[1], sys.argv[2], sys.argv[3]
bg = tuple(int(hexbg.lstrip('#')[i:i+2], 16) for i in (0, 2, 4))
im = Image.open(src).convert("RGBA")
flat = Image.new("RGB", im.size, bg)
flat.paste(im, mask=im.split()[3])
flat.save(dst)
PY
}

build_sources() {
  echo "▸ sources — rasterising SVG masters to 1024 PNGs"
  render "$DESIGN/woody_logo_foreground.svg" "$DESIGN/woody_logo_foreground.png"
  render "$DESIGN/woody_logo_monochrome.svg" "$DESIGN/woody_logo_monochrome.png"
  cp "$DESIGN/woody_logo_foreground.png" "$ASSETS/woody_logo_foreground.png"
  cp "$DESIGN/woody_logo_monochrome.png" "$ASSETS/woody_logo_monochrome.png"
  # Full (terracotta-baked) master used as the FLI image_path — flattened, no alpha.
  render "$DESIGN/woody_icon_full.svg" "$DESIGN/.tmp_full.png"
  flatten "$DESIGN/.tmp_full.png" "$DESIGN/woody_logo_full.png" "$TERRACOTTA"
  rm -f "$DESIGN/.tmp_full.png"
  echo "  ✓ foreground / monochrome / full"
}

run_flutter_launcher_icons() {
  echo "▸ flutter — dart run flutter_launcher_icons"
  ( cd "$REPO_ROOT" && dart run flutter_launcher_icons )
  # Sweep retired iOS-18 appearance PNGs (custom AppIcon-*-1024 single-size
  # format). FLI rewrites Contents.json to its standard multi-size set and emits
  # Icon-App-*.png, so these would otherwise linger as unreferenced orphans.
  find "$APPICON" -maxdepth 1 -name 'AppIcon-*.png' -delete
  echo "  ✓ FLI run + stale appearance PNGs swept"
}

build_notification() {
  echo "▸ notification — rasterising white silhouette ic_stat_woody per density"
  # Standard 24dp notification icon scaled per density bucket.
  local densities=("mdpi:24" "hdpi:36" "xhdpi:48" "xxhdpi:72" "xxxhdpi:96")
  for d in "${densities[@]}"; do
    local bucket="${d%%:*}" px="${d##*:}"
    render "$DESIGN/woody_notification.svg" \
           "$ANDROID_RES/drawable-$bucket/ic_stat_woody.png" "$px"
  done
  echo "  ✓ ic_stat_woody @ mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi"
}

case "${1:-all}" in
  sources)      build_sources ;;
  flutter)      run_flutter_launcher_icons ;;
  notification) build_notification ;;
  all)          build_sources; run_flutter_launcher_icons; build_notification ;;
  *) echo "usage: $0 [sources|flutter|notification|all]" >&2; exit 2 ;;
esac
echo "✓ done (${1:-all})"
