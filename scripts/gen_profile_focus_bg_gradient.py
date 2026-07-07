#!/usr/bin/env python3
"""Profile backdrop scrims — React profile.tsx gradient layers (FHD 1920x1080).

Outputs:
  profile_focus_bg_gradient.png — focus layer: left-to-right scrim only
  profile_bg_bottom_vignette.png  — always-on bottom vignette (smooth, no hard band)
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

UI = Path(__file__).resolve().parents[1] / "images" / "ui"
W, H = 1920, 1080


def _horiz_alpha(x: int) -> float:
    """focusedProfile: linear-gradient(to right, black/0.9 0% … transparent 60%)."""
    t = x / max(1, W - 1)
    if t <= 0.2:
        return 0.9 + (0.7 - 0.9) * (t / 0.2)
    if t <= 0.4:
        u = (t - 0.2) / 0.2
        return 0.7 + (0.4 - 0.7) * u
    if t <= 0.6:
        u = (t - 0.4) / 0.2
        return 0.4 + (0.0 - 0.4) * u
    return 0.0


def _bottom_alpha(y: int) -> float:
    """Always-on layer: linear-gradient(to bottom, transparent 0%, black/0.5 70%, black/0.9 200%)."""
    t = y / max(1, H - 1)
    if t <= 0.7:
        return 0.5 * (t / 0.7)
    u = (t - 0.7) / (2.0 - 0.7)
    if u > 1.0:
        u = 1.0
    return 0.5 + u * 0.4


def _write_rgba(path: Path, alpha_fn) -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            a = alpha_fn(x, y)
            if a > 0.0:
                px[x, y] = (0, 0, 0, int(a * 255 + 0.5))
    img.save(path, "PNG", optimize=True)


def main() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    horiz = UI / "profile_focus_bg_gradient.png"
    bottom = UI / "profile_bg_bottom_vignette.png"
    _write_rgba(horiz, lambda x, _y: _horiz_alpha(x))
    _write_rgba(bottom, lambda _x, y: _bottom_alpha(y))
    print(f"Wrote {horiz}")
    print(f"Wrote {bottom}")


if __name__ == "__main__":
    main()
