#!/usr/bin/env python3
"""Rasterize React sidebar SVGs — grey idle PNGs + white active masks for blendColor."""
import os
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "images" / "ui"
SIZE = 96
RENDER_SIZE = 512
IDLE_FILL = "#8F8F8F"
REACT_REPO = ROOT.parent.parent / "lg-samsung-tv-player"
REACT_IMAGE_TS = REACT_REPO / "src" / "utils" / "images" / "image.ts"
CHROME = os.environ.get("CHROME_BIN", "google-chrome")

ICON_PAIRS = {
    "home": ("HOME", "HOME_FOCUSED"),
    "search": ("SEARCH", "SEARCH_FOCUSED"),
    "tv": ("TV", "TV_FOCUSED"),
    "play": ("PLAY", "PLAY_FOCUSED"),
    "list": ("LIST", "LIST_FOCUSED"),
    "profile": ("PROFILE", "PROFILE_FOCUSED"),
    "reels": ("NEW_RELEASE", "NEW_RELEASE_FOCUSED"),
    "live_tv": ("LIVE_TV", "LIVE_TV_FOCUSED"),
}


def extract_svg(src: str, key: str) -> str:
    marker = f"  {key}: {{"
    start = src.index(marker)
    img_pos = src.index("img:", start)
    i = img_pos + 4
    while i < len(src) and src[i].isspace():
        i += 1
    quote = src[i]
    i += 1
    parts = []
    while i < len(src) and src[i] != quote:
        parts.append(src[i])
        i += 1
    return "".join(parts)


def normalize_svg(svg: str, fill: str) -> str:
    svg = svg.replace("var(--primary-500)", fill)
    svg = re.sub(r'fill="#8F8F8F"', f'fill="{fill}"', svg, flags=re.I)
    svg = re.sub(r'fill="#1163fb"', f'fill="{fill}"', svg, flags=re.I)
    svg = re.sub(r'fill="white"', f'fill="{fill}"', svg, flags=re.I)
    if svg.count("<path") > 1:
        paths = re.findall(r"<path[^>]*/>", svg)
        if paths:
            seen = set()
            unique = []
            for p in paths:
                d_match = re.search(r'd="([^"]+)"', p)
                if not d_match:
                    continue
                d = d_match.group(1)
                if d in seen:
                    continue
                seen.add(d)
                unique.append(re.sub(r'fill="[^"]*"', f'fill="{fill}"', p))
            inner = "".join(unique)
            vb = re.search(r'viewBox="([^"]+)"', svg)
            view_box = vb.group(1) if vb else "0 0 24 24"
            svg = f'<svg viewBox="{view_box}" xmlns="http://www.w3.org/2000/svg">{inner}</svg>'
    if not svg.lstrip().startswith("<svg"):
        svg = f'<svg xmlns="http://www.w3.org/2000/svg">{svg}</svg>'
    return svg


def padded_viewbox(vb: str, ratio: float = 0.18) -> str:
    parts = vb.split()
    if len(parts) != 4:
        return vb
    x, y, w, h = map(float, parts)
    pad = max(w, h) * ratio
    return f"{x - pad} {y - pad} {w + pad * 2} {h + pad * 2}"


def svg_for_render(svg: str, fill: str) -> str:
    inner = normalize_svg(svg, fill)
    vb = re.search(r'viewBox="([^"]+)"', inner)
    view_box = padded_viewbox(vb.group(1)) if vb else "0 0 24 24"
    path_body = inner[inner.find(">") + 1 : inner.rfind("</svg>")]
    return (
        f'<svg viewBox="{view_box}" width="{RENDER_SIZE}" height="{RENDER_SIZE}" '
        f'xmlns="http://www.w3.org/2000/svg">{path_body}</svg>'
    )


def chrome_shot(svg_html: str, shot_path: Path, html_path: Path) -> Image.Image:
    html_path.write_text(svg_html, encoding="utf-8")
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            f"--window-size={RENDER_SIZE},{RENDER_SIZE}",
            f"--screenshot={shot_path}",
            html_path.as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return Image.open(shot_path).convert("RGB")


def html_wrap(inner: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; }}
body {{ width:{RENDER_SIZE}px; height:{RENDER_SIZE}px; background:#000; }}
svg {{ width:{RENDER_SIZE}px; height:{RENDER_SIZE}px; display:block; }}
</style></head><body>{inner}</body></html>"""


def rgb_to_rgba(raw: Image.Image, mode: str) -> Image.Image:
    out = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    px_in = raw.load()
    px_out = out.load()
    w, h = raw.size
    idle = (143, 143, 143)
    for y in range(h):
        for x in range(w):
            r, g, b = px_in[x, y]
            if r + g + b <= 40:
                continue
            if mode == "idle":
                px_out[x, y] = (idle[0], idle[1], idle[2], 255)
            else:
                px_out[x, y] = (255, 255, 255, 255)
    if mode == "active":
        alpha = out.split()[3]
        alpha = alpha.filter(ImageFilter.MaxFilter(3))
        out.putalpha(alpha)
    return out


def fit_square(img: Image.Image, size: int, pad_ratio: float = 0.08, binarize_white: bool = False) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    crop = img.crop(bbox)
    cw, ch = crop.size
    inner = int(size * (1 - pad_ratio * 2))
    scale = min(inner / cw, inner / ch)
    nw = max(1, int(cw * scale))
    nh = max(1, int(ch * scale))
    scaled = crop.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(scaled, ((size - nw) // 2, (size - nh) // 2), scaled)
    if binarize_white:
        px = out.load()
        for y in range(size):
            for x in range(size):
                if px[x, y][3] > 48:
                    px[x, y] = (255, 255, 255, 255)
                else:
                    px[x, y] = (0, 0, 0, 0)
    return out


def render_icon(name: str, svg: str, fill: str, suffix: str, html_path: Path, shot_path: Path) -> None:
    inner = svg_for_render(svg, fill)
    raw = chrome_shot(html_wrap(inner), shot_path, html_path)
    mode = "idle" if suffix == "" else "active"
    rgba = fit_square(rgb_to_rgba(raw, mode), SIZE, binarize_white=(mode == "active"))
    OUT.mkdir(parents=True, exist_ok=True)
    out_name = f"menu_{name}.png" if suffix == "" else f"menu_{name}_active.png"
    rgba.save(OUT / out_name)


def main() -> None:
    if not REACT_IMAGE_TS.is_file():
        raise SystemExit(f"React image.ts not found: {REACT_IMAGE_TS}")
    src = REACT_IMAGE_TS.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for name, (idle_key, active_key) in ICON_PAIRS.items():
            idle_svg = extract_svg(src, idle_key)
            active_svg = extract_svg(src, active_key)
            render_icon(name, idle_svg, IDLE_FILL, "", tmp_path / f"{name}_idle.html", tmp_path / f"{name}_idle.raw.png")
            render_icon(name, active_svg, "#ffffff", "_active", tmp_path / f"{name}_act.html", tmp_path / f"{name}_act.raw.png")
            print(f"  menu_{name}.png + menu_{name}_active.png")
    print("Wrote idle (grey) + active (white mask) menu icons to", OUT)


if __name__ == "__main__":
    main()
