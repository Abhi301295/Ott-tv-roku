#!/usr/bin/env python3
"""Reels dummy poster — parity with React Images.THUMBNAIL (image.ts)."""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REACT_IMAGE_TS = ROOT.parent / "lg-samsung-tv-player-lg-dev" / "src" / "utils" / "images" / "image.ts"
UI = ROOT / "images" / "ui"
OUT_PNG = UI / "reels_thumb_placeholder.png"
W, H = 608, 1080
BG_RGB = (250, 250, 251)  # #fafafb from Images.THUMBNAIL


def _extract_svg(primary: str) -> str:
    text = REACT_IMAGE_TS.read_text(encoding="utf-8")
    m = re.search(r"THUMBNAIL:\s*\{\s*img:\s*`([^`]+)`", text, re.S)
    if not m:
        raise SystemExit(f"THUMBNAIL svg not found in {REACT_IMAGE_TS}")
    return m.group(1).replace("var(--primary-500)", primary)


def _render_svg(svg_path: Path) -> Image.Image:
    try:
        import gi

        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
    except Exception as exc:  # pragma: no cover
        raise SystemExit(
            "GdkPixbuf required to rasterize SVG (install gir1.2-gdkpixbuf-2.0)."
        ) from exc

    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(svg_path), 1400, 1400, True)
    w, h = pb.get_width(), pb.get_height()
    rowstride = pb.get_rowstride()
    data = bytes(pb.get_pixels())
    return Image.frombytes("RGBA", (w, h), data, "raw", "RGBA", rowstride)


def _cover_crop(im: Image.Image, w: int, h: int) -> Image.Image:
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - w) // 2
    top = (nh - h) // 2
    return im.crop((left, top, left + w, top + h))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary", default="#0b75e0", help="Theme primary-500 hex")
    args = parser.parse_args()

    UI.mkdir(parents=True, exist_ok=True)
    svg = _extract_svg(args.primary)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".svg", delete=False, encoding="utf-8") as tmp:
        tmp.write(svg)
        svg_path = Path(tmp.name)

    logo = _cover_crop(_render_svg(svg_path), W, H)
    svg_path.unlink(missing_ok=True)
    bg = Image.new("RGB", (W, H), BG_RGB)
    bg.paste(logo, (0, 0), logo)
    bg.save(OUT_PNG, optimize=True)
    print(f"Wrote {OUT_PNG} ({W}x{H}) primary={args.primary}")


if __name__ == "__main__":
    main()
