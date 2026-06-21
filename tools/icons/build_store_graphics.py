#!/usr/bin/env python3
"""build_store_graphics.py — Google Play / App Store listing graphics.

Outputs (design/store/):
  - play_listing_icon_512.png        512x512 store icon (terracotta + white box,
                                      opaque — mirrors the on-device app icon).
  - play_feature_graphic_1024x500.png 1024x500 feature graphic: the white box
                                      mark + "Woody" wordmark + tagline on a warm
                                      terracotta gradient (not just a centred
                                      logo — a designed hero).

The box mark in BOTH outputs is rasterised from the SAME SVG master the app icon
uses (woody_logo_foreground.svg / woody_icon_full.svg) so the listing art is
pixel-identical to the launcher icon — no hand-drawn lookalike.

Brand: white cabinet glyph on terracotta #C27A5F (the CLAUDE.md brand accent).
Requires: rsvg-convert + python3 with Pillow. Run from the repo root:
    python3 tools/icons/build_store_graphics.py
"""
import os
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DESIGN = os.path.join(REPO, "design", "logo")
OUT = os.path.join(REPO, "design", "store")
FONTS = os.path.join(REPO, "assets", "google_fonts")
os.makedirs(OUT, exist_ok=True)

TERRACOTTA = (194, 122, 95)          # #C27A5F
WHITE = (255, 255, 255)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def render_svg(svg_name, px):
    """Rasterise an SVG master to a square px×px RGBA image."""
    tmp = os.path.join(OUT, ".tmp_svg.png")
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px),
                    os.path.join(DESIGN, svg_name), "-o", tmp], check=True)
    im = Image.open(tmp).convert("RGBA")
    os.remove(tmp)
    return im


def white_box(px):
    """The white cabinet glyph (from the app-icon foreground SVG), tight-cropped."""
    im = render_svg("woody_logo_foreground.svg", px)
    return im.crop(im.getbbox())


# ── 512 listing icon — rasterise the unified app-icon SVG, flatten to opaque ──
def build_icon_512():
    im = render_svg("woody_icon_full.svg", 512)
    flat = Image.new("RGB", im.size, TERRACOTTA)   # drop alpha (store icon = opaque)
    flat.paste(im, mask=im.split()[3])
    out = os.path.join(OUT, "play_listing_icon_512.png")
    flat.save(out)
    print("  ✓", os.path.relpath(out, REPO))


# ── helpers ──────────────────────────────────────────────────────────────────
def diagonal_gradient(w, h, tl, tr, bl, br):
    """Smooth 2D gradient via a 2x2 bicubic upscale."""
    small = Image.new("RGB", (2, 2))
    small.putpixel((0, 0), tl); small.putpixel((1, 0), tr)
    small.putpixel((0, 1), bl); small.putpixel((1, 1), br)
    return small.resize((w, h), Image.Resampling.BICUBIC)


def soft_radial(w, h, cx, cy, rad, color, max_alpha):
    """A soft radial blob (for glow / vignette), returned as RGBA."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rad, cy - rad, cx + rad, cy + rad],
                                  fill=color + (max_alpha,))
    return layer.filter(ImageFilter.GaussianBlur(rad * 0.45))


def scale_to_h(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.Resampling.LANCZOS)


# ── 1024x500 feature graphic ─────────────────────────────────────────────────
def build_feature_graphic():
    SS = 3                                   # supersample for crisp edges/text
    W, H = 1024 * SS, 500 * SS
    box = white_box(1400)                    # high-res white glyph, tight-cropped

    # 1. warm terracotta gradient (light top-left → deep bottom-right)
    img = diagonal_gradient(
        W, H,
        tl=(216, 154, 130), tr=(190, 118, 92),
        bl=(186, 114, 89),  br=(148, 80, 58),
    ).convert("RGBA")

    # 2. soft light glow behind the logo (left third)
    img = Image.alpha_composite(
        img, soft_radial(W, H, int(W * 0.22), int(H * 0.46),
                         int(H * 0.55), (255, 238, 224), 70))

    # 3. corner vignette for depth
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(vig).rectangle([0, 0, W, H], fill=(60, 28, 16, 60))
    vig.paste((0, 0, 0, 0), (0, 0),
              soft_radial(W, H, W // 2, H // 2, int(H * 0.92), (255, 255, 255), 255))
    img = Image.alpha_composite(img, vig)

    # 4. oversized faint glyph watermark bleeding off the right edge
    wm = scale_to_h(box, int(H * 1.18))
    wlayer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wlayer.paste(wm, (int(W * 0.72), int(H * 0.16)), wm)
    wlayer.putalpha(wlayer.split()[3].point(lambda a: int(a * 0.09)))
    img = Image.alpha_composite(img, wlayer)

    # 5. logo glyph (white) with a soft drop shadow, vertically centred, left
    logo = scale_to_h(box, int(286 * SS))
    lx, ly = int(60 * SS), (H - logo.height) // 2
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dark = Image.new("RGBA", logo.size, (70, 32, 18, 255))
    dark.putalpha(logo.split()[3])
    sh.paste(dark, (lx, ly + int(10 * SS)), dark)
    sh = sh.filter(ImageFilter.GaussianBlur(11 * SS / 3))
    sh.putalpha(sh.split()[3].point(lambda a: int(a * 0.42)))
    img = Image.alpha_composite(img, sh)
    img.paste(logo, (lx, ly), logo)

    # 6. text block (wordmark + tagline), vertically centred as a group
    d = ImageDraw.Draw(img)
    tx = int(384 * SS)
    f_word = font("PlusJakartaSans-ExtraBold.ttf", int(132 * SS))
    f_tag = font("Inter-Medium.ttf", int(38 * SS))
    word, tag = "Woody", "Sifatli mebellar — bir joyda"

    wb = d.textbbox((0, 0), word, font=f_word)
    tb = d.textbbox((0, 0), tag, font=f_tag)
    wh, th = wb[3] - wb[1], tb[3] - tb[1]
    gap = int(24 * SS)
    top = (H - (wh + gap + th)) // 2

    # wordmark (with a subtle legibility shadow)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((tx + int(2 * SS), top - wb[1] + int(3 * SS)),
                                word, font=f_word, fill=(60, 28, 16, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4 * SS / 3))
    img = Image.alpha_composite(img, shadow)
    d = ImageDraw.Draw(img)
    d.text((tx, top - wb[1]), word, font=f_word, fill=WHITE)

    # tagline
    ty = top + wh + gap
    d.text((tx, ty - tb[1]), tag, font=f_tag, fill=(255, 246, 240))

    out_img = img.convert("RGB").resize((1024, 500), Image.Resampling.LANCZOS)
    out = os.path.join(OUT, "play_feature_graphic_1024x500.png")
    out_img.save(out)
    print("  ✓", os.path.relpath(out, REPO))


if __name__ == "__main__":
    print("▸ store graphics")
    build_icon_512()
    build_feature_graphic()
    print("✓ done")
