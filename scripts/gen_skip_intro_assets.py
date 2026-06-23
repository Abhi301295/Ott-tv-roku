#!/usr/bin/env python3
"""Skip Intro pill assets — parity with video/index.tsx skip button styles."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"

W, H = 220, 64
RADIUS = 8  # radius-8 = 0.5rem


def rounded_rect_outline(draw, xy, radius, outline, width=1):
    draw.rounded_rectangle(xy, radius=radius, outline=outline, width=width)


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # bg-[rgba(60,60,60,0.7)]
    pill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle(
        (0, 0, W - 1, H - 1), radius=RADIUS, fill=(60, 60, 60, 178)
    )
    pill.save(OUT / "video_pill.png")

    # ring-2 ring-white/70 — 2px outline, white @ 70% opacity
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rounded_rect_outline(
        ImageDraw.Draw(ring),
        (1, 1, W - 2, H - 2),
        RADIUS,
        outline=(255, 255, 255, 178),
        width=2,
    )
    ring.save(OUT / "skip_intro_ring.png")


if __name__ == "__main__":
    main()
