#!/usr/bin/env python3
"""Profile backdrop — single full-screen linear gradient (React Images.BG linearGradient id=a)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

UI = Path(__file__).resolve().parents[1] / "images" / "ui"
W, H = 1920, 1080


def _hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def main() -> None:
    # Smooth top-to-bottom: #0a0f2c -> #0d1b4f @50% -> #050814
    top = _hex_rgb("0a0f2c")
    mid = _hex_rgb("0d1b4f")
    bot = _hex_rgb("050814")

    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / max(1, H - 1)
        if t < 0.5:
            u = t / 0.5
            row = tuple(_lerp(top[i], mid[i], u) for i in range(3))
        else:
            u = (t - 0.5) / 0.5
            row = tuple(_lerp(mid[i], bot[i], u) for i in range(3))
        for x in range(W):
            px[x, y] = row

    UI.mkdir(parents=True, exist_ok=True)
    out = UI / "profile_default_bg_base.png"
    img.save(out, "PNG", optimize=True)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
