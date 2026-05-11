#!/usr/bin/env python3
"""
Master PNG'dan launcher icon manba fayllarini yaratadi:
  - woody_logo_foreground.png  (W markaziy 65%'da, atrofi transparent)
  - woody_logo_monochrome.png  (Android 13+ themed icons uchun siluyet)
  - woody_logo_1024.png        (master'ni 1024x1024'ga upscale)

Foydalanish:
    python3 tools/prepare_icons.py

Manba: assets/logo/woody_logo.png (transparent fon, RGBA)
Talab: Pillow paketi
    python3 -m pip install --user Pillow

Bu skript ishlagandan keyin:
    dart run flutter_launcher_icons
"""
from pathlib import Path
from PIL import Image

LOGO_DIR = Path(__file__).resolve().parent.parent / "assets" / "logo"
SRC = LOGO_DIR / "woody_logo.png"
CANVAS = 1024
SAFE_ZONE = 0.65  # W markaziy 65% kanvasda — Android adaptive safe zone


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Manba topilmadi: {SRC}")

    master = Image.open(SRC).convert("RGBA")
    print(f"Manba: {SRC.name} {master.size}")

    # 1) High-quality upscale to 1024 (manba kichik bo'lsa)
    if master.size != (CANVAS, CANVAS):
        upscaled = master.resize((CANVAS, CANVAS), Image.LANCZOS)
        upscaled.save(LOGO_DIR / "woody_logo_1024.png", optimize=True)
        print(f"  -> woody_logo_1024.png ({CANVAS}x{CANVAS})")
        master = upscaled

    # 2) Foreground: W markaziy SAFE_ZONE qismida, atrofi transparent
    safe = int(CANVAS * SAFE_ZONE)
    w_small = master.resize((safe, safe), Image.LANCZOS)
    fg = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = ((CANVAS - safe) // 2, (CANVAS - safe) // 2)
    fg.paste(w_small, offset, w_small)
    fg.save(LOGO_DIR / "woody_logo_foreground.png", optimize=True)
    print(f"  -> woody_logo_foreground.png (W {safe}x{safe} in {CANVAS}x{CANVAS})")

    # 3) Monochrome: foreground'ning alfa kanalidan solid qora silhouette
    mono = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    black = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    mono.paste(black, (0, 0), fg.split()[-1])
    mono.save(LOGO_DIR / "woody_logo_monochrome.png", optimize=True)
    print("  -> woody_logo_monochrome.png (pure black silhouette)")

    print("\nTayyor. Endi:  dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
