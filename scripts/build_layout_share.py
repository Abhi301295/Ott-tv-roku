#!/usr/bin/env python3
"""Build QA share zips for ThemeConfig values that are still static (not BE flags).

API-driven (admin can flip in business config — no share zip needed):
  enableHomeBanner, enableSideBarMenu, enableTrailerOnBanner, enableCardFocus, …

Static (need a separate channel zip per variant for QA):
  reelLayout                  DEFAULT | NEW_UI | CLEAN_UI
  heroBannerStyle             PAGE_FLIP | CINEMATIC_ZOOM | PARALLAX_SLIDE
                              (forces ThemeHeroBannerStyle; bypasses trailer→cinematic map)
  cardFocusTrailerPlayback    ENABLED | DISABLED
                              (old Genre Ott Banner path only)

Usage:
  python3 scripts/build_layout_share.py all
  python3 scripts/build_layout_share.py reelLayout-NEW_UI
  python3 scripts/build_layout_share.py list

Output: out/share/ott-tv-roku_<slug>.zip
"""
from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "source/lib/theme/ThemeConfig.brs"
OUT_SHARE = ROOT / "out/share"
APP_NAME = "ott-tv-roku"

# slug → patches: ThemeFn → return expression (TC_* helper call)
BUILDS: dict[str, dict[str, str]] = {
    # ── reelLayout (theme.config.ts — fully static) ──────────────────────────
    "reelLayout-DEFAULT": {
        "ThemeReelLayout": "TC_ReelLayoutDefault()",
    },
    "reelLayout-NEW_UI": {
        "ThemeReelLayout": "TC_ReelLayoutNewUi()",
    },
    "reelLayout-CLEAN_UI": {
        "ThemeReelLayout": "TC_ReelLayoutCleanUi()",
    },
    # ── heroBannerStyle (force static; Netflix home carousel) ────────────────
    "heroBannerStyle-PAGE_FLIP": {
        "ThemeHeroBannerStyle": "TC_HeroPageFlip()",
    },
    "heroBannerStyle-CINEMATIC_ZOOM": {
        "ThemeHeroBannerStyle": "TC_HeroCinematicZoom()",
    },
    "heroBannerStyle-PARALLAX_SLIDE": {
        "ThemeHeroBannerStyle": "TC_HeroParallaxSlide()",
    },
    # ── cardFocusTrailerPlayback (old Genre Banner; card-focus uses API) ─────
    "cardFocusTrailerPlayback-ENABLED": {
        "ThemeCardFocusTrailerPlayback": "TC_CardFocusTrailerEnabled()",
    },
    "cardFocusTrailerPlayback-DISABLED": {
        "ThemeCardFocusTrailerPlayback": "TC_CardFocusTrailerDisabled()",
    },
}

ZIP_DIRS = ("source", "components", "images")
ZIP_OPTIONAL_DIRS = ("fonts", "locale")
MANIFEST = "manifest"


def replace_theme_fn(text: str, fn_name: str, return_expr: str) -> str:
    """Replace a Theme*() as string function body with a single return."""
    pattern = rf"(function {re.escape(fn_name)}\(\) as string\n)(.*?)(\nend function)"
    repl = rf"\1    return {return_expr}\3"
    new, n = re.subn(pattern, repl, text, count=1, flags=re.DOTALL)
    if n != 1:
        raise RuntimeError(f"Failed to patch {fn_name} (matches={n})")
    return new


def patch_theme(text: str, patches: dict[str, str]) -> str:
    for fn_name, return_expr in patches.items():
        text = replace_theme_fn(text, fn_name, return_expr)
    return text


def zip_channel(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()

    def add_tree(zf: zipfile.ZipFile, folder: Path) -> None:
        if not folder.is_dir():
            return
        for path in folder.rglob("*"):
            if not path.is_file():
                continue
            if path.name in (".gitkeep", ".DS_Store"):
                continue
            zf.write(path, path.relative_to(ROOT))

    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        manifest = ROOT / MANIFEST
        if manifest.is_file():
            zf.write(manifest, MANIFEST)
        for name in ZIP_DIRS:
            add_tree(zf, ROOT / name)
        for name in ZIP_OPTIONAL_DIRS:
            folder = ROOT / name
            if folder.is_dir() and any(
                p.is_file() and p.name != ".gitkeep" for p in folder.rglob("*")
            ):
                add_tree(zf, folder)
        config = ROOT / "config.json"
        if config.is_file():
            zf.write(config, "config.json")


def build_slug(slug: str) -> Path:
    if slug not in BUILDS:
        raise SystemExit(f"Unknown build {slug!r}. Use: list | all | <slug>")

    patches = BUILDS[slug]
    original = THEME.read_text(encoding="utf-8")
    dest = OUT_SHARE / f"{APP_NAME}_{slug}.zip"

    print(f"==> {slug}")
    for fn, expr in patches.items():
        print(f"    {fn} → {expr}")

    try:
        THEME.write_text(patch_theme(original, patches), encoding="utf-8")
        subprocess.run(["make", "validate"], cwd=ROOT, check=True)
        zip_channel(dest)
    finally:
        THEME.write_text(original, encoding="utf-8")

    size_mb = dest.stat().st_size / (1024 * 1024)
    print(f"==> Built {dest} ({size_mb:.1f}M)")
    return dest


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(
            f"Usage: {sys.argv[0]} <slug|all|list>\n"
            f"Slugs: {', '.join(BUILDS)}"
        )

    arg = sys.argv[1].strip()
    if arg == "list":
        for slug in BUILDS:
            print(slug)
        return

    if arg == "all":
        for slug in BUILDS:
            build_slug(slug)
        print(f"\nAll builds in {OUT_SHARE}/")
        return

    build_slug(arg)


if __name__ == "__main__":
    main()
