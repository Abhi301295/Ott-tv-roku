#!/usr/bin/env python3
"""
Up Next cutout assets — parity heroBanner.tsx (155×220, clip + 14px right radius).
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT_IMG = Path(__file__).resolve().parents[1] / "images" / "ui"
W, H = 155, 220
R = 14
TLX = W * 0.18
BLX = W * 0.04
SCALE = 4


def shape_polygon(s):
    ws, hs = W * s, H * s
    rs, tlx, blx = R * s, TLX * s, BLX * s
    cx = ws - rs
    pts = [(tlx, 0), (cx, 0)]
    for deg in range(270, 361, 2):
        rad = math.radians(deg)
        pts.append((cx + rs * math.cos(rad), rs + rs * math.sin(rad)))
    for y in range(int(rs), int(hs - rs), 2):
        pts.append((ws, y))
    cy = hs - rs
    for deg in range(0, 91, 2):
        rad = math.radians(deg)
        pts.append((cx + rs * math.cos(rad), cy + rs * math.sin(rad)))
    pts.append((blx, hs))
    return pts


def raster_alpha_mask():
    """White shape on black — roBitmap.SetAlphaMask uses red channel as alpha."""
    ws, hs = int(W * SCALE), int(H * SCALE)
    alpha = Image.new("L", (ws, hs), 0)
    ImageDraw.Draw(alpha).polygon(shape_polygon(SCALE), fill=255)
    small = alpha.resize((W, H), Image.Resampling.LANCZOS)
    rgb = Image.new("RGB", (W, H), (0, 0, 0))
    rgb.paste((255, 255, 255), mask=small)
    return rgb


def raster_mask_rgba():
    ws, hs = int(W * SCALE), int(H * SCALE)
    alpha = Image.new("L", (ws, hs), 0)
    ImageDraw.Draw(alpha).polygon(shape_polygon(SCALE), fill=255)
    small = alpha.resize((W, H), Image.Resampling.LANCZOS)
    rgba = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rgba.paste((255, 255, 255, 255), mask=small)
    return rgba


def raster_left_edge():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i in range(401):
        t = i / 400.0
        y = t * H
        x = TLX + (BLX - TLX) * t
        draw.ellipse((x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=(255, 255, 255, 70))
    return img


def raster_shadow():
    pad = 40
    cw, ch = W + pad * 2, H + pad * 2
    ox, oy = pad - 6, pad + 4
    sil = raster_mask_rgba().split()[3]
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste((0, 0, 0, 178), (int(ox), int(oy)), sil)
    return canvas.filter(ImageFilter.GaussianBlur(radius=14))


def raster_grad_overlay():
    """Bottom fade only — parity heroBanner linear-gradient(to top, black 75% at 0%, transparent 55%)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  # 55% from bottom is transparent; lower 55% fades from transparent → 75% black.
    fade_top = int(H * 0.45 + 0.5)
    max_a = int(0.75 * 255)
    for y in range(H):
        if y < fade_top:
            a = 0
        else:
            t = (y - fade_top) / float(H - fade_top)
            a = int(max_a * t + 0.5)
        row = [(0, 0, 0, a)] * W
        for x in range(W):
            img.putpixel((x, y), row[x])
    return img


def raster_blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def raster_stage():
    return Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))


if __name__ == "__main__":
    OUT_IMG.mkdir(parents=True, exist_ok=True)
    raster_blank().save(OUT_IMG / "upnext_blank.png")
    raster_stage().save(OUT_IMG / "upnext_stage.png")
    raster_alpha_mask().save(OUT_IMG / "upnext_alpha_mask.png")
    raster_cutout = raster_mask_rgba()
    raster_cutout.save(OUT_IMG / "upnext_cutout_mask.png")
    raster_grad_overlay().save(OUT_IMG / "upnext_grad_overlay.png")
    raster_left_edge().save(OUT_IMG / "upnext_left_edge.png")
    raster_shadow().save(OUT_IMG / "upnext_shadow.png")
    print("Wrote upnext_blank.png, upnext_alpha_mask.png, upnext_cutout_mask.png, upnext_grad_overlay.png, upnext_left_edge.png, upnext_shadow.png")
