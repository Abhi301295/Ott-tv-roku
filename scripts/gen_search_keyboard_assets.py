#!/usr/bin/env python3
"""Rounded search keyboard fills + L/R/bottom panel shadow (no top halo)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"

KEY_SIZES = [(60, 70), (55, 70), (70, 70), (300, 70), (220, 70)]
INNER_RADIUS = 10

# Letter-layout panel @ FHD LARGE — must match SearchKeyboard.brs LayoutPanel().
# maxRowW=748, panelPadX=4 → panelW=756; 4 key rows, panelPadBottom=0 → panelH=352.
PANEL_SHADOW_W = 756
PANEL_SHADOW_H = 352
PANEL_SHADOW_RADIUS = 16

# L/R only — keep in sync with SR_PanelShadowSpread() / SR_PanelShadowBlurH().
SHADOW_SPREAD_H = 8
SHADOW_BLUR_H = 8

# Bottom only — keep in sync with SR_PanelShadowDropY() / SR_PanelShadowBlurB().
SHADOW_DROP = 16
SHADOW_BLUR_B = 12
SHADOW_ALPHA_H = 90
SHADOW_ALPHA_B = 165


def rounded_fill(w: int, h: int, radius: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=(255, 255, 255, 255))
    return img


def _panel_mask(cw: int, ch: int, ix0: int, iy0: int, ix1: int, iy1: int, radius: int) -> Image.Image:
    panel = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(panel).rounded_rectangle((ix0, iy0, ix1, iy1), radius=radius, fill=255)
    return panel


def _blur_panel_layer(
    cw: int, ch: int, ix0: int, iy0: int, ix1: int, iy1: int, radius: int, blur_r: int, alpha: int
) -> tuple[Image.Image, Image.Image]:
    panel = _panel_mask(cw, ch, ix0, iy0, ix1, iy1, radius)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste((0, 0, 0, alpha), (0, 0, cw, ch), panel)
    blurred = canvas.filter(ImageFilter.GaussianBlur(radius=blur_r))
    px = blurred.load()
    ppx = panel.load()
    for y in range(ch):
        for x in range(cw):
            if ppx[x, y] > 128:
                px[x, y] = (0, 0, 0, 0)
    return blurred, panel


def _punch_interior(px, panel: Image.Image, cw: int, ch: int) -> None:
    ppx = panel.load()
    for y in range(ch):
        for x in range(cw):
            if ppx[x, y] > 128:
                px[x, y] = (0, 0, 0, 0)


def panel_lrb_shadow(w: int, h: int, radius: int) -> Image.Image:
    """L/R and bottom shadows composited separately so spread only affects sides."""
    spread_h = SHADOW_SPREAD_H
    drop_b = SHADOW_DROP
    blur_h = SHADOW_BLUR_H
    blur_b = SHADOW_BLUR_B

    cw = w + (2 * spread_h)
    ch = h + drop_b + blur_b

    ix0, iy0 = spread_h, 0
    ix1, iy1 = ix0 + w - 1, h - 1

    result = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))

    # Left / right — narrow blur, no bottom contribution.
    lr, panel = _blur_panel_layer(cw, ch, ix0, iy0, ix1, iy1, radius, blur_h, SHADOW_ALPHA_H)
    lrpx = lr.load()
    for y in range(ch):
        for x in range(ix0, ix1 + 1):
            lrpx[x, y] = (0, 0, 0, 0)
    top_clip = min(blur_h + 2, radius)
    for y in range(top_clip):
        for x in range(ix0 + radius, ix1 - radius + 1):
            lrpx[x, y] = (0, 0, 0, 0)
    result = Image.alpha_composite(result, lr)

    # Bottom — separate drop + wider blur, independent of L/R spread.
    bot, panel = _blur_panel_layer(cw, ch, ix0, iy0, ix1, iy1, radius, blur_b, SHADOW_ALPHA_B)
    if drop_b > 0:
        shifted = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        shifted.paste(bot, (0, drop_b // 2))
        bot = shifted
        _punch_interior(bot.load(), panel, cw, ch)
    botpx = bot.load()
    corner_floor = h - radius
    for y in range(corner_floor):
        for x in range(cw):
            botpx[x, y] = (0, 0, 0, 0)

    return Image.alpha_composite(result, bot)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for w, h in KEY_SIZES:
        path = OUT / f"search_key_fill_{w}x{h}.png"
        rounded_fill(w, h, INNER_RADIUS).save(path)
        print("Wrote", path.name)
    shadow = OUT / "search_keyboard_shadow.png"
    panel_lrb_shadow(PANEL_SHADOW_W, PANEL_SHADOW_H, PANEL_SHADOW_RADIUS).save(shadow)
    print("Wrote", shadow.name)


if __name__ == "__main__":
    main()
