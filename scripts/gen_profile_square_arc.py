#!/usr/bin/env python3
"""
Square profile assets — selected state: outer theme border + inset inner progress ring.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"
SIZE = 150
FRAMES = 151
PERIM = 580
# Outer theme border (React bw-2 border-primary-700) at card edge.
BORDER_INSET = 1
BORDER_RECT = 148
BORDER_RADIUS = 12
BORDER_STROKE = 2
# Inner progress ring inset — padding between outer theme border and inner ring.
RING_INSET = 12
RING_RECT = 126
RING_RADIUS = 10
STROKE = 4
SS = 4


def mask_rgba(size: int, radius: int) -> Image.Image:
    big = size * 4
    alpha = Image.new("L", (big, big), 0)
    ImageDraw.Draw(alpha).rounded_rectangle((0, 0, big - 1, big - 1), radius=radius * 4, fill=255)
    small = alpha.resize((size, size), Image.Resampling.LANCZOS)
    small = small.point(lambda a: 255 if a > 96 else 0)
    rgba = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rgba.paste((255, 255, 255, 255), mask=small)
    return rgba


def ramp_rgba() -> Image.Image:
    big = SIZE * 4
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=12 * 4, fill=255)
    grad = Image.new("L", (big, big))
    for y in range(big):
        a = int(255 * (1.0 - y / (big - 1)))
        for x in range(big):
            grad.putpixel((x, y), a)
    combined = Image.new("L", (big, big))
    for y in range(big):
        for x in range(big):
            combined.putpixel((x, y), alpha.getpixel((x, y)) * grad.getpixel((x, y)) // 255)
    small = combined.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    rgba = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rgba.paste((255, 255, 255, 255), mask=small)
    return rgba


def _line_points(x0: float, y0: float, x1: float, y1: float, steps: int) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(steps):
        t = i / steps
        pts.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    return pts


def _arc_points(cx: float, cy: float, r: float, a0: float, a1: float, steps: int) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(steps):
        t = i / steps
        a = a0 + (a1 - a0) * t
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rounded_rect_path(inset: float, rect: float, radius: float) -> list[tuple[float, float]]:
    x, y = inset, inset
    w, h = rect, rect
    r = radius
    x1, y1 = x + r, y
    x2, y2 = x + w - r, y
    x3, y3 = x + w, y + r
    x4, y4 = x + w, y + h - r
    x5, y5 = x + w - r, y + h
    x6, y6 = x + r, y + h
    x7, y7 = x, y + h - r
    x8, y8 = x, y + r
    cx_tr, cy_tr = x + w - r, y + r
    cx_br, cy_br = x + w - r, y + h - r
    cx_bl, cy_bl = x + r, y + h - r
    cx_tl, cy_tl = x + r, y + r

    pts: list[tuple[float, float]] = []
    pts.extend(_line_points(x1, y1, x2, y2, 180))
    pts.extend(_arc_points(cx_tr, cy_tr, r, -math.pi / 2, 0.0, 48))
    pts.extend(_line_points(x3, y3, x4, y4, 180))
    pts.extend(_arc_points(cx_br, cy_br, r, 0.0, math.pi / 2, 48))
    pts.extend(_line_points(x5, y5, x6, y6, 180))
    pts.extend(_arc_points(cx_bl, cy_bl, r, math.pi / 2, math.pi, 48))
    pts.extend(_line_points(x7, y7, x8, y8, 180))
    pts.extend(_arc_points(cx_tl, cy_tl, r, math.pi, 3 * math.pi / 2, 48))
    return pts


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
    radius = width * scale / 2
    scaled = [(px * scale, py * scale) for px, py in pts]
    if len(scaled) >= 2:
        draw.line(scaled, fill=color, width=width * scale, joint="curve")
    if round_cap and scaled:
        draw.ellipse(
            (scaled[-1][0] - radius, scaled[-1][1] - radius, scaled[-1][0] + radius, scaled[-1][1] + radius),
            fill=color,
        )
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def render_outer_border() -> Image.Image:
    """Uniform 2px rounded ring — stroke PNG was uneven/clipped on Roku."""
    big = SIZE * SS
    r_out = 12 * SS
    bw = BORDER_STROKE * SS
    r_in = max(1, r_out - bw)

    outer = Image.new("L", (big, big), 0)
    inner = Image.new("L", (big, big), 0)
    ImageDraw.Draw(outer).rounded_rectangle((0, 0, big - 1, big - 1), radius=r_out, fill=255)
    ImageDraw.Draw(inner).rounded_rectangle(
        (bw, bw, big - 1 - bw, big - 1 - bw), radius=r_in, fill=255
    )

    ring = Image.new("L", (big, big), 0)
    o_load = outer.load()
    i_load = inner.load()
    r_load = ring.load()
    for y in range(big):
        for x in range(big):
            if o_load[x, y] and not i_load[x, y]:
                r_load[x, y] = 255

    small = ring.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    small = small.point(lambda a: 255 if a > 128 else 0)
    rgba = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rgba.paste((255, 255, 255, 255), mask=small)
    return rgba


def render_track() -> Image.Image:
    pts = rounded_rect_path(RING_INSET, RING_RECT, RING_RADIUS)
    dark = draw_stroke(pts, (0, 0, 0, 80), STROKE)
    light = draw_stroke(pts, (255, 255, 255, 110), STROKE)
    return Image.alpha_composite(dark, light)


def render_arc(dash_len: float) -> Image.Image:
    pts = rounded_rect_path(RING_INSET, RING_RECT, RING_RADIUS)
    cum, geo = path_lengths(pts)
    length = dash_len * (geo / PERIM) if PERIM > 0 else dash_len
    partial = truncate_path(pts, cum, length)
    return draw_stroke(partial, (59, 130, 246, 255), STROKE, round_cap=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    mask_rgba(SIZE, 12).save(OUT / "profile_sq_mask.png")
    mask_rgba(138, 10).save(OUT / "profile_sq_inner_mask.png")
    ramp_rgba().save(OUT / "profile_sq_ramp.png")
    render_outer_border().save(OUT / "profile_sq_border.png")
    render_track().save(OUT / "profile_sq_track.png")
    for i in range(FRAMES):
        frac = i / (FRAMES - 1)
        render_arc(frac * PERIM).save(OUT / f"profile_sq_arc_{i:03d}.png")

    pts = rounded_rect_path(RING_INSET, RING_RECT, RING_RADIUS)
    _, geo = path_lengths(pts)
    track = Image.open(OUT / "profile_sq_track.png").convert("RGBA")
    ys = [y for y in range(SIZE) if any(track.getpixel((x, y))[3] > 8 for x in range(SIZE))]
    print(f"Wrote profile_sq_* to {OUT} ({FRAMES} arc frames)")
    print(f"  ring geom={geo:.1f} PERIM={PERIM} track ymax={max(ys) if ys else 'none'}")


if __name__ == "__main__":
    main()
