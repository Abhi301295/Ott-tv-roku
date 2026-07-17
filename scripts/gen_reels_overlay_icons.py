#!/usr/bin/env python3
"""Reels overlay + NEW_UI social icons/cards — parity with ReelDetailPanel.tsx SVGs.

Icons are rasterized from the same Lucide/Material paths as React via GdkPixbuf
(Chrome headless was clipping the bottom ~1/3 of every glyph).
Rounded card fill/border PNGs use rounded-[24px] at exact NEW_UI sizes.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402

UI = Path(__file__).resolve().parents[1] / "images" / "ui"
BLUE = (0, 0, 255, 255)
WHITE = (255, 255, 255, 255)
SS = 4

# ReelDetailPanel.tsx NEW_UI SVG paths (viewBox 0 0 24 24).
SVG_HEART = (
    '<path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 '
    '7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>'
)
SVG_COMMENT = (
    '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>'
)
SVG_MUSIC = (
    '<path d="M9 18V5l12-2v13"/>'
    '<circle cx="6" cy="18" r="3"/>'
    '<circle cx="18" cy="16" r="3"/>'
)
SVG_USER = (
    '<path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 '
    '0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>'
)


def _draw_play(view: int, scale: int, fill: tuple[int, int, int, int]) -> Image.Image:
    size = view * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / view
    pts = [(8 * s, 5 * s), (8 * s, 19 * s), (19 * s, 12 * s)]
    draw.polygon(pts, fill=fill)
    return img


def _draw_pause(view: int, scale: int, fill: tuple[int, int, int, int]) -> Image.Image:
    size = view * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / view
    for x0, y0, x1, y1 in [(6, 5, 10, 19), (14, 5, 18, 19)]:
        draw.rectangle([x0 * s, y0 * s, x1 * s, y1 * s], fill=fill)
    return img


def _svg_doc(body: str, stroke: str | None, fill: str, stroke_width: float = 2.0) -> str:
    # viewBox 0 0 24 24 matches React Lucide/Material — full glyph weight in the box.
    attrs = f'fill="{fill}"'
    if stroke:
        attrs += (
            f' stroke="{stroke}" stroke-width="{stroke_width}" '
            'stroke-linecap="round" stroke-linejoin="round"'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" {attrs}>{body}</svg>'
    )


def _svg_render(svg: str, out_size: int) -> Image.Image:
    """Rasterize SVG with librsvg/GdkPixbuf — full glyph, no Chrome bottom crop."""
    render = max(out_size * 8, 256)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False, encoding="utf-8") as tmp:
        tmp.write(svg)
        path = tmp.name
    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, render, render, True)
    Path(path).unlink(missing_ok=True)
    w, h, n = pb.get_width(), pb.get_height(), pb.get_n_channels()
    rowstride = pb.get_rowstride()
    mode = "RGBA" if n == 4 else "RGB"
    raw = Image.frombytes(mode, (w, h), bytes(pb.get_pixels()), "raw", mode, rowstride)
    img = raw.convert("RGBA")
    # Drop near-black baked backgrounds if any.
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and r < 8 and g < 8 and b < 8:
                px[x, y] = (0, 0, 0, 0)
    return img.resize((out_size, out_size), Image.Resampling.LANCZOS)


def _export(src: Image.Image, out: Path, w: int, h: int) -> None:
    if src.size != (w, h):
        src = src.resize((w, h), Image.Resampling.LANCZOS)
    src.save(out, "PNG", optimize=True)
    print(f"Wrote {out.name} ({w}x{h})")


def aa_rounded_fill(w: int, h: int, radius: int) -> Image.Image:
    W, H = w * SS, h * SS
    R = radius * SS
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, W - 1, H - 1), radius=R, fill=WHITE)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def aa_rounded_outline(w: int, h: int, radius: int, stroke: int = 2) -> Image.Image:
    W, H = w * SS, h * SS
    R = radius * SS
    S = max(1, stroke * SS + SS // 2)
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, W - 1, H - 1), radius=R, fill=255)
    md.rounded_rectangle((S, S, W - 1 - S, H - 1 - S), radius=max(0, R - S), fill=0)
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    big.paste(WHITE, mask=mask)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def aa_corner_mask(size: int, corner: str) -> Image.Image:
    """Opaque page-bg wedge covering the sharp corner outside a quarter-circle."""
    S = size * SS
    big = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    # Fill square then cut the quarter-circle (transparent = keep video).
    draw.rectangle([0, 0, S - 1, S - 1], fill=(10, 10, 10, 255))
    # Quarter-circle centered on the inner corner of the mask tile.
    if corner == "tl":
        bbox = [0, 0, S * 2, S * 2]
        start, end = 180, 270
    elif corner == "tr":
        bbox = [-S, 0, S, S * 2]
        start, end = 270, 360
    elif corner == "bl":
        bbox = [0, -S, S * 2, S]
        start, end = 90, 180
    else:  # br
        bbox = [-S, -S, S, S]
        start, end = 0, 90
    # Cut pie by drawing transparent — use mask subtract.
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).pieslice(bbox, start=start, end=end, fill=255)
    # Keep opaque only where mask is 0 (outside the arc).
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = out.load()
    src = big.load()
    m = mask.load()
    for y in range(S):
        for x in range(S):
            if m[x, y] == 0:
                px[x, y] = src[x, y]
    return out.resize((size, size), Image.Resampling.LANCZOS)


def aa_avatar_placeholder(size: int = 64) -> Image.Image:
    """React: 64 circle bg-gray-500/50, border-2 border-white/30, Material user 32 @ op-50."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # bg-gray-500/50
    d.ellipse([0, 0, S - 1, S - 1], fill=(107, 114, 128, 128))
    # border-2 border-white/30
    bw = max(2, 2 * SS)
    inset = bw // 2
    d.ellipse(
        [inset, inset, S - 1 - inset, S - 1 - inset],
        outline=(255, 255, 255, 77),
        width=bw,
    )
    # Material person path (same as ReelDetailPanel.tsx), 32px @ opacity-50, centered.
    glyph = _svg_render(_svg_doc(SVG_USER, None, "#ffffff"), 32)
    gpx = glyph.load()
    gw, gh = glyph.size
    for y in range(gh):
        for x in range(gw):
            r, g, b, a = gpx[x, y]
            if a > 0:
                gpx[x, y] = (r, g, b, int(a * 0.5))
    glyph = glyph.resize((32 * SS, 32 * SS), Image.Resampling.LANCZOS)
    ox = (S - glyph.size[0]) // 2
    oy = (S - glyph.size[1]) // 2
    img.alpha_composite(glyph, (ox, oy))
    return img.resize((size, size), Image.Resampling.LANCZOS)


def circle_stroke_ring(size: int, stroke: int = 2) -> Image.Image:
    S = size * SS
    sw = max(1, stroke * SS)
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([0, 0, S - 1, S - 1], fill=255)
    md.ellipse([sw, sw, S - 1 - sw, S - 1 - sw], fill=0)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(WHITE, mask=mask)
    return out.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    UI.mkdir(parents=True, exist_ok=True)

    _export(_draw_play(24, 8 * 80 // 24, BLUE), UI / "reels_play_80.png", 80, 80)
    _export(_draw_play(24, 8 * 80 // 24, WHITE), UI / "ic_v_play.png", 160, 160)
    _export(_draw_pause(24, 8 * 50 // 24, BLUE), UI / "reels_pause_50.png", 50, 50)
    _export(_draw_pause(24, 8 * 50 // 24, WHITE), UI / "ic_v_pause.png", 100, 100)

    heart_outline = _svg_doc(SVG_HEART, "#ffffff", "none", 2.0)
    heart_filled = _svg_doc(SVG_HEART, "#ef4444", "#ef4444", 2.0)
    comment = _svg_doc(SVG_COMMENT, "#ffffff", "none", 2.0)
    music = _svg_doc(SVG_MUSIC, "#ffffff", "none", 2.5)
    user = _svg_doc(SVG_USER, None, "#ffffff")

    for size in (32, 48):
        _export(_svg_render(heart_outline, size), UI / f"reels_heart_outline_{size}.png", size, size)
        _export(_svg_render(heart_filled, size), UI / f"reels_heart_filled_{size}.png", size, size)
        _export(_svg_render(comment, size), UI / f"reels_comment_{size}.png", size, size)
    _export(_svg_render(music, 32), UI / "reels_music_32.png", 32, 32)
    _export(_svg_render(user, 32), UI / "reels_user_32.png", 32, 32)

    for sz in (64, 80, 92, 96):
        circle_stroke_ring(sz, 2).save(UI / f"reels_circle_ring_{sz}.png", optimize=True)
        print(f"Wrote reels_circle_ring_{sz}.png")

    # Avatar fallback circle with border (64) — used when no photo.
    aa_avatar_placeholder(64).save(UI / "reels_avatar_placeholder_64.png", optimize=True)
    print("Wrote reels_avatar_placeholder_64.png")

    for w, h in ((400, 112), (400, 148), (400, 80), (543, 144), (543, 128), (543, 96)):
        aa_rounded_fill(w, h, 24).save(UI / f"reels_card_fill_{w}x{h}.png", optimize=True)
        aa_rounded_outline(w, h, 24, stroke=2).save(UI / f"reels_card_border_{w}x{h}.png", optimize=True)
    print("Wrote reels_card_* 400x112 / 400x148 / 400x80 / 543x*")

    # CommentSidebar.tsx CommentItem: rounded-2xl (16), border 2px; max 3-line card 618x208.
    cw, ch, cr = 618, 220, 16
    aa_rounded_fill(cw, ch, cr).save(UI / f"reels_comment_card_fill_{cw}x{ch}.png", optimize=True)
    aa_rounded_outline(cw, ch, cr, stroke=2).save(UI / f"reels_comment_card_border_{cw}x{ch}.png", optimize=True)
    print(f"Wrote reels_comment_card_* {cw}x{ch} r={cr}")

    # CLEAN_UI genre pill: rounded-full border-white/30, transparent fill (px-4 py-1.5).
    for w, h in ((120, 32), (160, 32), (200, 32), (240, 32), (280, 32)):
        aa_rounded_fill(w, h, h // 2).save(UI / f"reels_genre_pill_fill_{w}x{h}.png", optimize=True)
        aa_rounded_outline(w, h, h // 2, stroke=1).save(UI / f"reels_genre_pill_ring_{w}x{h}.png", optimize=True)
    print("Wrote reels_genre_pill_*")

    # DEFAULT OldActionButton / OldDetailCard: rounded-2xl (16).
    for w, h, name in ((250, 150, "old_btn"), (516, 170, "old_title"), (516, 160, "old_info")):
        aa_rounded_fill(w, h, 16).save(UI / f"reels_{name}_fill_{w}x{h}.png", optimize=True)
        aa_rounded_outline(w, h, 16, stroke=2).save(UI / f"reels_{name}_border_{w}x{h}.png", optimize=True)
    print("Wrote reels_old_* cards")

    # Creator badge: rounded-lg (8), primary blendColor at runtime.
    for w in (120, 160, 200, 240, 280, 320):
        aa_rounded_fill(w, 36, 8).save(UI / f"reels_creator_badge_fill_{w}x36.png", optimize=True)
    print("Wrote reels_creator_badge_fill_*")

    # Verified badge: bg #ffcc00 rounded-full — native size, never upscale (keeps Label sharp).
    vw, vh = 72, 20
    ver = aa_rounded_fill(vw, vh, vh // 2)
    # Tint white fill → #ffcc00
    px = ver.load()
    for y in range(vh):
        for x in range(vw):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (255, 204, 0, a)
    ver.save(UI / "reels_verified_pill_72x20.png", optimize=True)
    print("Wrote reels_verified_pill_72x20.png")

    # Video outer corner masks at 12px (all four — bottom was clipping before height fix).
    for corner in ("tl", "tr", "bl", "br"):
        aa_corner_mask(12, corner).save(UI / f"round_corner_{corner}.png", optimize=True)
        print(f"Wrote round_corner_{corner}.png")


if __name__ == "__main__":
    main()
