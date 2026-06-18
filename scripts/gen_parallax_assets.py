#!/usr/bin/env python3
"""Parallax hero UI assets — frost strip + rounded thumbs + capsule dots."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "images" / "ui"


def rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = xy
    r = radius
    draw.rounded_rectangle((x0, y0, x1, y1), radius=r, fill=fill, outline=outline, width=width)


def frost_panel(w=800, h=58, radius=12):
    """Frosted pill — parity rgba(255,255,255,0.08) + 1px rgba(255,255,255,0.1) border."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (1, 1, w - 2, h - 2), radius, fill=(255, 255, 255, 20), outline=(255, 255, 255, 26), width=1)
    # subtle top highlight
    hi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    rounded_rect(hd, (2, 2, w - 3, h // 2), max(1, radius - 2), fill=(255, 255, 255, 12))
    return Image.alpha_composite(img, hi)


def frost_shadow(w=800, h=58, radius=12):
    pad = 12
    cw, ch = w + pad * 2, h + pad * 2
    sil = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sil).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste((0, 0, 0, 70), (pad, pad), sil)
    return canvas.filter(ImageFilter.GaussianBlur(radius=8))


def thumb_shell(tw, th, border_px, border_a, radius=6):
    """Rounded thumb frame (poster sits inset by border_px)."""
    fw, fh = tw + border_px * 2, th + border_px * 2
    img = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if border_px > 0:
        rounded_rect(
            draw,
            (0, 0, fw - 1, fh - 1),
            radius,
            fill=None,
            outline=(255, 255, 255, border_a),
            width=border_px,
        )
    return img


def thumb_mask_rgba(tw, th, radius=6):
    img = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, tw - 1, th - 1), radius=radius, fill=(255, 255, 255, 255))
    return img


def thumb_mask_rgb(tw, th, radius=6):
    """White shape on black — MaskGroup maskUri (red channel alpha)."""
    rgba = thumb_mask_rgba(tw, th, radius)
    alpha = rgba.split()[3]
    rgb = Image.new("RGB", (tw, th), (0, 0, 0))
    rgb.paste((255, 255, 255), mask=alpha)
    return rgb


def capsule(w, h, color):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, w - 1, h - 1), radius=w // 2, fill=color)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frost_panel().save(OUT / "parallax_frost_panel.png")
    frost_shadow().save(OUT / "parallax_frost_shadow.png")
    thumb_shell(72, 42, 2, 204).save(OUT / "parallax_thumb_active.png")
    thumb_shell(52, 32, 1, 51).save(OUT / "parallax_thumb_idle.png")
    thumb_mask_rgb(68, 38).save(OUT / "parallax_thumb_mask_lg.png")
    thumb_mask_rgb(50, 30).save(OUT / "parallax_thumb_mask_sm.png")
    capsule(4, 28, (255, 255, 255, 255)).save(OUT / "parallax_dot_active.png")
    capsule(4, 10, (255, 255, 255, 77)).save(OUT / "parallax_dot_idle.png")
    print("Wrote parallax assets →", OUT)


if __name__ == "__main__":
    main()
