#!/usr/bin/env python3
"""Rounded search keyboard fills + L/R/bottom panel shadow (no top halo)."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

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

# Search result card — parity search-horizontalcard.tsx rounded-xl on neutral-1000 page.
SEARCH_CARD_W = 280
SEARCH_CARD_H = 150
SEARCH_CARD_RADIUS = 12
SEARCH_CARD_BORDER = 3


def search_card_corner(quadrant: str, radius: int) -> Image.Image:
    """White corner nub mask — tint with page bg via Poster.blendColor (FocusFrame parity)."""
    img = Image.new("RGBA", (radius, radius), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    pies = {
        "tl": (0, 0, 2 * radius, 2 * radius, 180, 270),
        "tr": (-radius, 0, radius - 1, 2 * radius, 270, 360),
        "bl": (0, -radius, 2 * radius, radius - 1, 90, 180),
        "br": (-radius, -radius, radius - 1, radius - 1, 0, 90),
    }
    args = pies[quadrant]
    d.pieslice(list(args[:4]), args[4], args[5], fill=(0, 0, 0, 0))
    return img


def search_card_focus_ring(w: int, h: int, radius: int, thickness: int) -> Image.Image:
    """Inset border ring sharing the clip radius — tint via blendColor (parity inset-0 border-3)."""
    outer = Image.new("L", (w, h), 0)
    inner = Image.new("L", (w, h), 0)
    ImageDraw.Draw(outer).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    inset = thickness
    inner_r = max(0, radius - inset)
    ImageDraw.Draw(inner).rounded_rectangle(
        (inset, inset, w - 1 - inset, h - 1 - inset), radius=inner_r, fill=255
    )
    ring = ImageChops.subtract(outer, inner)
    return Image.merge("RGBA", (ring, ring, ring, ring))


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
    for q in ("tl", "tr", "bl", "br"):
        path = OUT / f"search_card_corner_{q}.png"
        search_card_corner(q, SEARCH_CARD_RADIUS).save(path)
        print("Wrote", path.name)
    ring = OUT / "search_card_focus_ring.png"
    search_card_focus_ring(SEARCH_CARD_W, SEARCH_CARD_H, SEARCH_CARD_RADIUS, SEARCH_CARD_BORDER).save(ring)
    print("Wrote", ring.name)


if __name__ == "__main__":
    main()
