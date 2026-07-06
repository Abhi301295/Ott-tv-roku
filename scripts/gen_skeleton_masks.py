#!/usr/bin/env python3
"""Skeleton shape masks and SkeletonBox wrapper glows (onboardingSkeleton.tsx)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"

# onboardingSkeleton.tsx boxShadow: 0 4px 10px rgba(0, 146, 255, 0.4)
# CSS blur-radius 10px ≈ Pillow GaussianBlur sigma 5 (not 10 — wider blur dilutes the halo).
GLOW_BLUR = 5
GLOW_OFFSET_Y = 4
GLOW_PAD = GLOW_BLUR + 14

# 190×22 name pill — extra horizontal + vertical pad; wider blur on the flat edges.
PILL_GLOW_BLUR = 12
PILL_GLOW_PAD_X = PILL_GLOW_BLUR + 28
PILL_GLOW_PAD_Y = PILL_GLOW_BLUR + 18


def rounded_mask(w: int, h: int, radius: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, w - 1, h - 1), radius=radius, fill=(255, 255, 255, 255)
    )
    return img


def _draw_shape(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, radius: int, w: int, h: int) -> None:
    if radius >= min(w, h) // 2:
        draw.ellipse((x0, y0, x1, y1), fill=(255, 255, 255, 255))
    else:
        draw.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=(255, 255, 255, 255))


def _punch_hole(img: Image.Image, x0: int, y0: int, x1: int, y1: int, radius: int, w: int, h: int) -> Image.Image:
    hole = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(hole)
    if radius >= min(w, h) // 2:
        draw.ellipse((x0, y0, x1, y1), fill=(255, 255, 255, 255))
    else:
        draw.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=(255, 255, 255, 255))
    spx = img.load()
    hpx = hole.load()
    for y in range(img.height):
        for x in range(img.width):
            if hpx[x, y][3] > 128:
                spx[x, y] = (0, 0, 0, 0)
    return img


def _normalize_peak_alpha(img: Image.Image, peak: int) -> Image.Image:
    px = img.load()
    max_a = 0
    for y in range(img.height):
        for x in range(img.width):
            max_a = max(max_a, px[x, y][3])
    if max_a <= 0:
        return img
    factor = peak / max_a
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (255, 255, 255, min(int(a * factor), peak))
    return img


def box_glow(w: int, h: int, radius: int, blur: int = GLOW_BLUR, pad_x: int = GLOW_PAD, pad_y: int = GLOW_PAD) -> Image.Image:
    """Outer-only halo mask — tint via Poster blendColor + opacity on device."""
    canvas_w = w + 2 * pad_x
    canvas_h = h + 2 * pad_y + GLOW_OFFSET_Y
    shadow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    sx0 = pad_x
    sy0 = pad_y + GLOW_OFFSET_Y
    sx1 = pad_x + w - 1
    sy1 = pad_y + h - 1 + GLOW_OFFSET_Y
    _draw_shape(draw, sx0, sy0, sx1, sy1, radius, w, h)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur))
    hx0 = pad_x
    hy0 = pad_y
    hx1 = pad_x + w - 1
    hy1 = pad_y + h - 1
    shadow = _punch_hole(shadow, hx0, hy0, hx1, hy1, radius, w, h)
    return _normalize_peak_alpha(shadow, 255)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # profile.tsx SkeletonBox borderRadius={9999} — 150×150 circle, 190×22 pill
    rounded_mask(150, 150, 75).save(OUT / "sk_avatar_150.png")
    rounded_mask(190, 22, 11).save(OUT / "sk_pill_190x22.png")
    box_glow(150, 150, 75).save(OUT / "sk_glow_avatar_150.png")
    box_glow(
        190,
        22,
        11,
        blur=PILL_GLOW_BLUR,
        pad_x=PILL_GLOW_PAD_X,
        pad_y=PILL_GLOW_PAD_Y,
    ).save(OUT / "sk_glow_pill_190x22.png")

    # userProfile.tsx Original card rounded-xl (cardRadius 12)
    rounded_mask(150, 150, 12).save(OUT / "sk_rounded_150_r12.png")
    box_glow(150, 150, 12).save(OUT / "sk_glow_rounded_150_r12.png")


if __name__ == "__main__":
    main()
