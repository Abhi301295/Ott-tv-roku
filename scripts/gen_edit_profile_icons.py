#!/usr/bin/env python3
"""Edit-profile popup assets + Lucide edit (pen-line) icon from userProfile.tsx.

Borders are supersampled (4× → LANCZOS) so rounded corners stay smooth on-device —
PIL 1× outlines look jagged on both straight edges and curves.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

UI = Path(__file__).resolve().parents[1] / "images" / "ui"
GRAY = (200, 200, 200, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersample factor for anti-aliased rounded shapes


def aa_rounded_outline(w: int, h: int, radius: int, stroke: int = 1) -> Image.Image:
    """White rounded stroke on transparent; downscaled for smooth edges.

    Stroke is an outer−inner rounded-rect difference. A small supersample pad on
    stroke width keeps corner arcs from looking thinner than straight edges after
    LANCZOS (curves lose more opaque coverage than flats under the same filter).
    """
    W, H = w * SS, h * SS
    R = radius * SS
    # +SS//2 ≈ half a destination pixel — equalizes perceived corner weight.
    S = max(1, stroke * SS + SS // 2)
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, W - 1, H - 1), radius=R, fill=255)
    inner_r = max(0, R - S)
    md.rounded_rectangle((S, S, W - 1 - S, H - 1 - S), radius=inner_r, fill=0)
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    big.paste(WHITE, mask=mask)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def aa_rounded_fill(w: int, h: int, radius: int) -> Image.Image:
    """White rounded fill on transparent; downscaled for smooth edges."""
    W, H = w * SS, h * SS
    R = radius * SS
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    draw.rounded_rectangle((0, 0, W - 1, H - 1), radius=R, fill=WHITE)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def draw_x(size: int, color: tuple[int, int, int, int], stroke: int = 2) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = int(size * 0.22)
    draw.line((pad, pad, size - pad, size - pad), fill=color, width=stroke)
    draw.line((size - pad, pad, pad, size - pad), fill=color, width=stroke)
    return img


def _arc_points(
    x0: float, y0: float, rx: float, ry: float, dx: float, dy: float, sweep: int, n: int = 16
) -> list[tuple[float, float]]:
    x1, y1 = x0 + dx, y0 + dy
    mx, my = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    vx, vy = x1 - x0, y1 - y0
    chord = math.hypot(vx, vy) or 1.0
    r = (rx + ry) / 2.0
    half = chord / 2.0
    h = math.sqrt(max(0.0, r * r - half * half))
    px, py = -vy / chord, vx / chord
    if sweep == 0:
        px, py = -px, -py
    cx, cy = mx + px * h, my + py * h
    a0 = math.atan2(y0 - cy, x0 - cx)
    a1 = math.atan2(y1 - cy, x1 - cx)
    if sweep == 1 and a1 < a0:
        a1 += 2 * math.pi
    if sweep == 0 and a0 < a1:
        a0 += 2 * math.pi
    pts = []
    for i in range(1, n + 1):
        t = i / float(n)
        a = a0 + (a1 - a0) * t
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_lucide_edit(size: int, color: tuple[int, int, int, int] = WHITE) -> Image.Image:
    view = 24.0
    scale = size / view
    stroke = max(2, int(round(2 * scale)))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def P(x: float, y: float) -> tuple[float, float]:
        return (x * scale, y * scale)

    draw.line([P(12, 20), P(21, 20)], fill=color, width=stroke)
    pen: list[tuple[float, float]] = [P(16.5, 3.5)]
    for x, y in _arc_points(16.5, 3.5, 2.121, 2.121, 3, 3, sweep=1):
        pen.append(P(x, y))
    pen.extend([P(7, 19), P(3, 20), P(4, 16), P(16.5, 3.5)])
    draw.line(pen, fill=color, width=stroke, joint="curve")
    return img


def main() -> None:
    UI.mkdir(parents=True, exist_ok=True)

    # editProfilePopup.tsx: rounded-3xl (24) card, bw-1 (1px) — exact on-screen size.
    aa_rounded_outline(602, 336, 24, stroke=1).save(UI / "edit_dialog_border_602.png", optimize=True)
    aa_rounded_fill(600, 334, 23).save(UI / "edit_dialog_card_600.png", optimize=True)

    # Input: rounded-xl (12), border-2 — exact 510×52 / 506×48.
    aa_rounded_outline(510, 52, 12, stroke=2).save(UI / "edit_field_border_510.png", optimize=True)
    aa_rounded_fill(506, 48, 11).save(UI / "edit_field_bg_506.png", optimize=True)

    draw_x(24, GRAY, 2).save(UI / "ic_edit_clear_24.png", optimize=True)
    draw_x(24, WHITE, 2).save(UI / "ic_edit_clear_24_white.png", optimize=True)
    draw_lucide_edit(96).save(UI / "profile_edit_icon.png", optimize=True)
    print("Wrote AA edit-dialog borders + field + icons")


if __name__ == "__main__":
    main()
