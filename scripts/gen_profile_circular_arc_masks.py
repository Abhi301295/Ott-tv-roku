#!/usr/bin/env python3
"""White alpha masks for the profile auto-select ring (themed fill applied at runtime)."""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"
FRAMES = 151


def arc_to_mask(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px_in = im.load()
    px_out = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px_in[x, y]
            if a < 24:
                continue
            px_out[x, y] = (255, 255, 255, a)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        src = OUT / f"profile_arc_{i:03d}.png"
        if not src.is_file():
            raise SystemExit(f"missing source frame: {src}")
        arc_to_mask(src).save(OUT / f"profile_arc_mask_{i:03d}.png")
    print(f"Wrote {FRAMES} masks to {OUT}")


if __name__ == "__main__":
    main()
