#!/usr/bin/env python3
"""build_onboarding_placeholders.py — aesthetic placeholder art for the customer
3D onboarding (pages 2 & 3). Replace with real furniture photography when ready.

Outputs (assets/images/):
  - onboarding_2.png   sofa illustration — "Explore world-class furniture"
  - onboarding_3.png   armchair + AR cube — "Design your space with AR"

Warm terracotta gradients + clean white furniture line/solid art, on-brand with
the app icon. Portrait 1080x1350 (4:5). Requires python3 + Pillow.
    python3 tools/icons/build_onboarding_placeholders.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "assets", "images")
os.makedirs(OUT, exist_ok=True)

SS = 2
W, H = 1080, 1350


def gradient(tl, tr, bl, br):
    small = Image.new("RGB", (2, 2))
    small.putpixel((0, 0), tl); small.putpixel((1, 0), tr)
    small.putpixel((0, 1), bl); small.putpixel((1, 1), br)
    return small.resize((W * SS, H * SS), Image.Resampling.BICUBIC).convert("RGBA")


def rr(d, x0, y0, x1, y1, r, fill):
    d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=fill)


def line(d, pts, w, fill):
    d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=int(w * SS), joint="curve")


def with_shadow(base, art):
    """Composite white art over base with a soft drop shadow underneath."""
    sh = art.split()[3]
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    dark = Image.new("RGBA", base.size, (60, 28, 16, 150))
    shadow.paste(dark, (0, int(14 * SS)), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10 * SS))
    out = Image.alpha_composite(base, shadow)
    return Image.alpha_composite(out, art)


def glow(base, cx, cy, rad, alpha=60):
    g = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse(
        [(cx - rad) * SS, (cy - rad) * SS, (cx + rad) * SS, (cy + rad) * SS],
        fill=(255, 240, 226, alpha))
    return Image.alpha_composite(base, g.filter(ImageFilter.GaussianBlur(rad * 0.5 * SS)))


WHITE = (255, 255, 255, 255)
SOFT = (255, 255, 255, 235)


def build_sofa():
    img = gradient((216, 152, 128), (198, 124, 96), (190, 116, 90), (168, 96, 70))
    img = glow(img, 540, 600, 460, 70)
    art = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    # back cushion, seat, arms, legs — a clean modern 3-seater silhouette
    rr(d, 250, 560, 830, 770, 56, WHITE)          # back
    rr(d, 210, 720, 870, 858, 46, WHITE)          # seat
    rr(d, 196, 628, 300, 900, 46, WHITE)          # left arm
    rr(d, 780, 628, 884, 900, 46, WHITE)          # right arm
    rr(d, 250, 884, 286, 944, 8, SOFT)            # legs
    rr(d, 794, 884, 830, 944, 8, SOFT)
    # two seat-cushion seams for a premium read
    line(d, [(360, 726), (360, 852)], 7, (198, 124, 96, 180))
    line(d, [(720, 726), (720, 852)], 7, (198, 124, 96, 180))
    out = with_shadow(img, art).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    p = os.path.join(OUT, "onboarding_2.png"); out.save(p)
    print("  ✓", os.path.relpath(p, REPO))


def build_armchair_ar():
    img = gradient((206, 134, 106), (190, 116, 88), (176, 100, 74), (150, 82, 60))
    img = glow(img, 540, 640, 440, 64)
    art = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    # armchair
    rr(d, 392, 560, 688, 770, 64, WHITE)          # back
    rr(d, 372, 728, 708, 856, 46, WHITE)          # seat
    rr(d, 356, 636, 446, 882, 44, WHITE)          # left arm
    rr(d, 634, 636, 724, 882, 44, WHITE)          # right arm
    rr(d, 404, 868, 440, 930, 8, SOFT)            # legs
    rr(d, 640, 868, 676, 930, 8, SOFT)
    # AR cube wireframe (suggests "place it in your room")
    cube = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(cube)
    ox, oy, s, dp = 720, 360, 150, 70             # origin, size, depth offset
    f = [(ox, oy), (ox + s, oy), (ox + s, oy + s), (ox, oy + s)]
    b = [(x + dp, y - dp) for x, y in f]
    for a, bb in zip(f, f[1:] + f[:1]):
        line(cd, [a, bb], 7, (255, 255, 255, 210))
    for a, bb in zip(b, b[1:] + b[:1]):
        line(cd, [a, bb], 7, (255, 255, 255, 130))
    for a, bb in zip(f, b):
        line(cd, [a, bb], 7, (255, 255, 255, 130))
    # dashed floor line under the chair → "room placement"
    for x in range(330, 760, 60):
        line(cd, [(x, 952), (x + 32, 952)], 6, (255, 255, 255, 150))
    art = Image.alpha_composite(art, cube)
    out = with_shadow(img, art).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    p = os.path.join(OUT, "onboarding_3.png"); out.save(p)
    print("  ✓", os.path.relpath(p, REPO))


if __name__ == "__main__":
    print("▸ onboarding placeholders")
    build_sofa()
    build_armchair_ar()
    print("✓ done")
