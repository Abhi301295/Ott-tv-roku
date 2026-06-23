#!/usr/bin/env python3
"""Reels play/pause icons — vector parity with React reels/index.tsx SVG paths."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

UI = Path(__file__).resolve().parents[1] / "images" / "ui"
BLUE = (0, 0, 255, 255)


def _draw_play(view: int, scale: int) -> Image.Image:
    size = view * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / view
    pts = [(8 * s, 5 * s), (8 * s, 19 * s), (19 * s, 12 * s)]
    draw.polygon(pts, fill=BLUE)
    return img


def _draw_pause(view: int, scale: int) -> Image.Image:
    size = view * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / view
    for x0, y0, x1, y1 in [(6, 5, 10, 19), (14, 5, 18, 19)]:
        draw.rectangle([x0 * s, y0 * s, x1 * s, y1 * s], fill=BLUE)
    return img


def _export(src: Image.Image, out: Path, w: int, h: int) -> None:
    if src.size != (w, h):
        src = src.resize((w, h), Image.Resampling.LANCZOS)
    src.save(out, "PNG", optimize=True)
    print(f"Wrote {out} ({w}x{h})")


def main() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    play_hi = _draw_play(24, 8 * 80 // 24)
    _export(play_hi, UI / "reels_play_80.png", 80, 80)
    _export(play_hi, UI / "ic_v_play.png", 160, 160)

    pause_hi = _draw_pause(24, 8 * 50 // 24)
    _export(pause_hi, UI / "reels_pause_50.png", 50, 50)
    _export(pause_hi, UI / "ic_v_pause.png", 100, 100)


if __name__ == "__main__":
    main()
