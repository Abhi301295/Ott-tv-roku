#!/usr/bin/env python3
"""Live TV hero buttons — 3× supersampled pills + lucide Play icons (livetv/index.tsx)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"
SCALE = 3


def _down(img: Image.Image, w: int, h: int) -> Image.Image:
    if img.size != (w * SCALE, h * SCALE):
        img = img.resize((w * SCALE, h * SCALE), Image.Resampling.LANCZOS)
    return img.resize((w, h), Image.Resampling.LANCZOS)


def _pill_fill(w: int, h: int, rgba: tuple[int, int, int, int]) -> Image.Image:
    W, H = w * SCALE, h * SCALE
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, W - 1, H - 1), radius=H // 2, fill=rgba)
    return _down(img, w, h)


def _pill_outline(w: int, h: int, rgba: tuple[int, int, int, int], stroke: int = 1) -> Image.Image:
    W, H = w * SCALE, h * SCALE
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    sw = max(1, stroke * SCALE)
    inset = sw // 2
    draw.rounded_rectangle(
        (inset, inset, W - 1 - inset, H - 1 - inset),
        radius=H // 2,
        outline=rgba,
        width=sw,
    )
    return _down(img, w, h)


def _pill_ring(btn_w: int, btn_h: int, rgba: tuple[int, int, int, int], ring: int = 4) -> Image.Image:
    w, h = btn_w + ring * 2, btn_h + ring * 2
    W, H = w * SCALE, h * SCALE
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    sw = max(1, ring * SCALE)
    inset = sw // 2
    draw.rounded_rectangle(
        (inset, inset, W - 1 - inset, H - 1 - inset),
        radius=H // 2,
        outline=rgba,
        width=sw,
    )
    return _down(img, w, h)


def _lucide_play_fill(size: int, rgba: tuple[int, int, int, int]) -> Image.Image:
    """Lucide Play path M5 5v14l14-7z on a 24×24 viewbox."""
    canvas = size * SCALE
    s = canvas / 24.0
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts = [(5 * s, 5 * s), (5 * s, 19 * s), (19 * s, 12 * s)]
    draw.polygon(pts, fill=rgba)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _lucide_play_stroke(size: int, rgba: tuple[int, int, int, int], stroke: int = 2) -> Image.Image:
    canvas = size * SCALE
    s = canvas / 24.0
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts = [(5 * s, 5 * s), (5 * s, 19 * s), (19 * s, 12 * s)]
    sw = max(1, int(stroke * s))
    for i in range(3):
        draw.line([pts[i], pts[(i + 1) % 3]], fill=rgba, width=sw)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    play_now_w, btn_h = 152, 44
    play_beg_w = 248

    _pill_fill(play_now_w, btn_h, (229, 0, 122, 255)).save(OUT / "livetv_play_fill.png")
    _pill_ring(play_now_w, btn_h, (229, 0, 122, 128), ring=4).save(OUT / "livetv_play_ring.png")

    _pill_outline(play_beg_w, btn_h, (255, 255, 255, 102), stroke=1).save(OUT / "livetv_pill_outline.png")
    _pill_outline(play_beg_w, btn_h, (255, 255, 255, 255), stroke=1).save(OUT / "livetv_pill_outline_focus.png")
    _pill_fill(play_beg_w - 2, btn_h - 2, (255, 255, 255, 255)).save(OUT / "livetv_pill_fill.png")
    _pill_ring(play_beg_w, btn_h, (255, 255, 255, 51), ring=4).save(OUT / "livetv_pill_ring.png")

    _lucide_play_fill(18, (255, 255, 255, 255)).save(OUT / "livetv_ic_play_fill.png")
    _lucide_play_stroke(18, (209, 213, 219, 255), stroke=2).save(OUT / "livetv_ic_play_stroke.png")
    _lucide_play_stroke(18, (255, 255, 255, 255), stroke=2).save(OUT / "livetv_ic_play_stroke_white.png")

    print("Wrote livetv hero button assets to", OUT)


if __name__ == "__main__":
    main()
