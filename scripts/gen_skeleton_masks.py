#!/usr/bin/env python3
"""Skeleton shape masks — same-size PNGs for Skeleton shapeUri (no scaleToFill distortion)."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"


def rounded_mask(w: int, h: int, radius: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, w - 1, h - 1), radius=radius, fill=(255, 255, 255, 255)
    )
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # profile.tsx SkeletonBox borderRadius={9999} — 150×150 circle, 190×22 pill
    rounded_mask(150, 150, 75).save(OUT / "sk_avatar_150.png")
    rounded_mask(190, 22, 11).save(OUT / "sk_pill_190x22.png")

    # userProfile.tsx Original card rounded-xl (cardRadius 12)
    rounded_mask(150, 150, 12).save(OUT / "sk_rounded_150_r12.png")


if __name__ == "__main__":
    main()
