#!/usr/bin/env bash
#
# build_app_icons.sh — regenerate Woody's launcher icons from the SVG masters.
#
# Pipeline (default `all`):
#   1. sources  — rasterise the SVG masters in design/logo/ to the 1024 PNG
#                 sources that flutter_launcher_icons consumes (foreground +
#                 monochrome land in both design/logo/ and assets/logo/).
#   2. flutter  — `dart run flutter_launcher_icons`: Android adaptive +
#                 monochrome (themed, A13+) and the iOS "any appearance" set.
#   3. ios      — render the three 1024 iOS appearance masters (any / dark /
#                 tinted) into AppIcon.appiconset and rewrite Contents.json to
#                 the single-size universal format with an `appearances` array
#                 per variant. flutter_launcher_icons does NOT emit iOS 18
#                 dark/tinted, so this step is what makes them real — and it
#                 MUST run after step 2, which reverts the iOS set to legacy.
#
# Usage:
#   tools/icons/build_app_icons.sh            # all three steps
#   tools/icons/build_app_icons.sh sources    # just refresh the PNG sources
#   tools/icons/build_app_icons.sh ios        # just re-apply the iOS-18 patch
#
# Requires: rsvg-convert (brew install librsvg) + python3 with Pillow.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DESIGN="$REPO_ROOT/design/logo"
ASSETS="$REPO_ROOT/assets/logo"
APPICON="$REPO_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Brand colours (must match pubspec flutter_launcher_icons + the SVGs).
NAVY_LIGHT="#1F2933"     # Android legacy + FLI source background (woody_logo_full.png)
IOS_LIGHT_BG="#FFFFFF"   # iOS "any / light" appearance background — bright, distinct
NAVY_DARK="#11181F"      # iOS dark-appearance background

need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ missing dependency: $1" >&2; exit 1; }; }
need rsvg-convert
need python3

# render <svg> <out.png>  — crisp 1024×1024 RGBA rasterisation.
render() { rsvg-convert -w 1024 -h 1024 "$1" -o "$2"; }

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
  # Full (navy-baked) master used as the FLI image_path — flattened, no alpha.
  render "$DESIGN/woody_icon_full.svg" "$DESIGN/.tmp_full.png"
  flatten "$DESIGN/.tmp_full.png" "$DESIGN/woody_logo_full.png" "$NAVY_LIGHT"
  rm -f "$DESIGN/.tmp_full.png"
  echo "  ✓ foreground / monochrome / full"
}

run_flutter_launcher_icons() {
  echo "▸ flutter — dart run flutter_launcher_icons"
  ( cd "$REPO_ROOT" && dart run flutter_launcher_icons )
}

build_ios_appearances() {
  echo "▸ ios — rendering appearance masters + rewriting Contents.json"
  # Any / light: WHITE background + terracotta glyph, alpha removed (doubles as
  # the App Store marketing icon, which must be opaque). Bright + distinct from
  # the dark home screen — woody_icon_full.svg's navy read as dark in light mode.
  render "$DESIGN/woody_icon_light.svg" "$APPICON/.tmp.png"
  flatten "$APPICON/.tmp.png" "$APPICON/AppIcon-1024.png" "$IOS_LIGHT_BG"
  # Dark: deeper navy background baked, alpha removed.
  render "$DESIGN/woody_icon_dark.svg" "$APPICON/.tmp.png"
  flatten "$APPICON/.tmp.png" "$APPICON/AppIcon-Dark-1024.png" "$NAVY_DARK"
  # Tinted: white grayscale glyph on TRANSPARENT — the system supplies the dark
  # plate and applies the user's tint by luminance. Alpha is kept on purpose.
  render "$DESIGN/woody_logo_monochrome.svg" "$APPICON/AppIcon-Tinted-1024.png"
  rm -f "$APPICON/.tmp.png"

  # Drop the legacy per-size PNGs flutter_launcher_icons emitted — the
  # single-size universal format downsamples the 1024 masters at build time.
  find "$APPICON" -maxdepth 1 -name 'Icon-App-*.png' -delete

  cat > "$APPICON/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-Dark-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-Tinted-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  echo "  ✓ AppIcon-1024 / -Dark-1024 / -Tinted-1024 + Contents.json"
}

case "${1:-all}" in
  sources) build_sources ;;
  flutter) run_flutter_launcher_icons ;;
  ios)     build_ios_appearances ;;
  all)     build_sources; run_flutter_launcher_icons; build_ios_appearances ;;
  *) echo "usage: $0 [sources|flutter|ios|all]" >&2; exit 2 ;;
esac
echo "✓ done (${1:-all})"
