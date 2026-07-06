#!/usr/bin/env python3
"""Circular profile ring masks + track (React netComponent geometry).

ringSize=166, avatarSize=150, strokeWidth=4, ringRadius=(ringSize-strokeWidth)/2.
Arc grows clockwise from 12 o'clock (SVG rotate(-90) parity).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"
SIZE = 166
STROKE = 4
FRAMES = 151
SS = 4
CENTER = SIZE / 2.0
RADIUS = (SIZE - STROKE) / 2.0
START = -math.pi / 2.0


def path_lengths(pts: list[tuple[float, float]]) -> tuple[list[float], float]:
    cum = [0.0]
    total = 0.0
    for i in range(1, len(pts)):
        dx = pts[i][0] - pts[i - 1][0]
        dy = pts[i][1] - pts[i - 1][1]
        total += math.hypot(dx, dy)
        cum.append(total)
    return cum, total


def truncate_path(pts: list[tuple[float, float]], cum: list[float], length: float) -> list[tuple[float, float]]:
    if length <= 0:
        return []
    if length >= cum[-1]:
        return pts[:]
    out = [pts[0]]
    for i in range(1, len(pts)):
        if cum[i] < length:
            out.append(pts[i])
            continue
        prev = pts[i - 1]
        cur = pts[i]
        seg = cum[i] - cum[i - 1]
        if seg <= 0:
            break
        t = (length - cum[i - 1]) / seg
        out.append((prev[0] + (cur[0] - prev[0]) * t, prev[1] + (cur[1] - prev[1]) * t))
        break
    return out


def circle_path(steps: int = 720) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(steps + 1):
        a = START + (2.0 * math.pi * i / steps)
        pts.append((CENTER + RADIUS * math.cos(a), CENTER + RADIUS * math.sin(a)))
    return pts


def partial_circle_path(frac: float) -> list[tuple[float, float]]:
    if frac <= 0.0:
        return []
    steps = max(8, int(720 * frac))
    pts: list[tuple[float, float]] = []
    end = START + (2.0 * math.pi * frac)
    for i in range(steps + 1):
        t = i / steps
        a = START + (end - START) * t
        pts.append((CENTER + RADIUS * math.cos(a), CENTER + RADIUS * math.sin(a)))
    return pts


def draw_stroke(
    pts: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    width: int,
    *,
    round_cap: bool = False,
) -> Image.Image:
    big = SIZE * SS
    scale = SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = width * scale / 2.0
    scaled = [(px * scale, py * scale) for px, py in pts]
    if len(scaled) >= 2:
        draw.line(scaled, fill=color, width=width * scale, joint="curve")
    if round_cap and scaled:
        cap = scaled[-1]
        draw.ellipse(
            (cap[0] - radius, cap[1] - radius, cap[0] + radius, cap[1] + radius),
            fill=color,
        )
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def to_mask(im: Image.Image) -> Image.Image:
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    px_in = src.load()
    px_out = out.load()
    for y in range(src.height):
        for x in range(src.width):
            _, _, _, a = px_in[x, y]
            if a < 24:
                continue
            px_out[x, y] = (255, 255, 255, a)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    full = circle_path()
    cum, perim = path_lengths(full)

    track = draw_stroke(full, (255, 255, 255, 255), STROKE)
    track.save(OUT / "avatar_ring.png")

    for i in range(FRAMES):
        frac = i / (FRAMES - 1)
        partial = partial_circle_path(frac)
        arc = draw_stroke(partial, (255, 255, 255, 255), STROKE, round_cap=(frac > 0.0))
        to_mask(arc).save(OUT / f"profile_arc_mask_{i:03d}.png")

    print(f"Wrote avatar_ring.png + {FRAMES} masks to {OUT}")
    print(f"  ringSize={SIZE} stroke={STROKE} radius={RADIUS:.1f} perim={perim:.1f}")


if __name__ == "__main__":
    main()
