#!/usr/bin/env python3
"""Bake portal-colored profile arc frames from white masks.

Gradient parity: React netComponent applies linearGradient in the circle's local
bbox, then paints the stroke with transform rotate(-90). Sample each arc pixel in
pre-rotation coordinates (inverse +90° about center) before mapping to the
diagonal gradient stops.
"""
import argparse
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"
FRAMES = 151


def parse_hex(s: str) -> tuple[int, int, int]:
    h = s.strip().lstrip("#")
    if len(h) == 8:
        h = h[:6]
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t + 0.5)


def lerp_rgb(c0, c1, t: float) -> tuple[int, int, int]:
    return lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t)


def gradient_rgb(t: float, primary, secondary, tertiary) -> tuple[int, int, int]:
    # React netComponent: stop 70% primary, 90% secondary, 100% tertiary.
    if t <= 0.7:
        return primary
    if t <= 0.9:
        f = (t - 0.7) / 0.2
        return lerp_rgb(primary, secondary, f)
    f = min(1.0, (t - 0.9) / 0.1)
    return lerp_rgb(secondary, tertiary, f)


def react_gradient_t(x: int, y: int, w: int, h: int) -> float:
    """objectBoundingBox linearGradient (0,0)→(100%,100%) on pre-rotated circle."""
    if w <= 1 or h <= 1:
        return 0.0
    cx = (w - 1) / 2.0
    cy = (h - 1) / 2.0
    dx = x - cx
    dy = y - cy
    # Inverse of SVG rotate(-90): local = rotate(+90) · (dx, dy)
    gx = cx - dy
    gy = cy + dx
    return max(0.0, min(1.0, (gx / (w - 1) + gy / (h - 1)) / 2.0))


def render_frame(mask_path: Path, primary, secondary, tertiary) -> Image.Image:
    mask = Image.open(mask_path).convert("RGBA")
    w, h = mask.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px_m = mask.load()
    px_o = out.load()
    for y in range(h):
        for x in range(w):
            _, _, _, a = px_m[x, y]
            if a < 24:
                continue
            t = react_gradient_t(x, y, w, h)
            rgb = gradient_rgb(t, primary, secondary, tertiary)
            px_o[x, y] = (*rgb, a)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bake pkg profile_arc_*.png for simulator fallback (portal hex overrides)."
    )
    parser.add_argument("--primary", default="#0b75e0")
    parser.add_argument("--secondary", default="#d355cb")
    parser.add_argument("--tertiary", default="#ff6b00")
    args = parser.parse_args()
    primary = parse_hex(args.primary)
    secondary = parse_hex(args.secondary)
    tertiary = parse_hex(args.tertiary)
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        mask = OUT / f"profile_arc_mask_{i:03d}.png"
        if not mask.is_file():
            raise SystemExit(f"missing {mask}")
        render_frame(mask, primary, secondary, tertiary).save(OUT / f"profile_arc_{i:03d}.png")
    print(f"Wrote {FRAMES} colored arcs to {OUT}")


if __name__ == "__main__":
    main()
