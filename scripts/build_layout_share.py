#!/usr/bin/env python3
"""Build QA share zips for ThemeConfig layout cases 1–6 (see ThemeConfig.brs presets)."""
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

# Parity with ThemeConfig.brs layout preset comments (cases 1–6).
CASES: dict[int, dict[str, str]] = {
    1: {
        "slug": "case01_netflix-home_netflix-header_cinematic-zoom",
        "home": "TC_HomeLayoutNetflix()",
        "header": "TC_HeaderNetflix()",
        "hero": "TC_HeroCinematicZoom()",
    },
    2: {
        "slug": "case02_netflix-home_netflix-header_page-flip",
        "home": "TC_HomeLayoutNetflix()",
        "header": "TC_HeaderNetflix()",
        "hero": "TC_HeroPageFlip()",
    },
    3: {
        "slug": "case03_netflix-home_netflix-header_parallax-slide",
        "home": "TC_HomeLayoutNetflix()",
        "header": "TC_HeaderNetflix()",
        "hero": "TC_HeroParallaxSlide()",
    },
    4: {
        "slug": "case04_netflix-home_sidebar-header_cinematic-zoom",
        "home": "TC_HomeLayoutNetflix()",
        "header": "TC_HeaderSidebar()",
        "hero": "TC_HeroCinematicZoom()",
    },
    5: {
        "slug": "case05_ott-home_netflix-header",
        "home": "TC_HomeLayoutOtt()",
        "header": "TC_HeaderNetflix()",
        "hero": "TC_HeroCinematicZoom()",
    },
    6: {
        "slug": "case06_ott-home_sidebar-header",
        "home": "TC_HomeLayoutOtt()",
        "header": "TC_HeaderSidebar()",
        "hero": "TC_HeroCinematicZoom()",
    },
}

ZIP_DIRS = ("source", "components", "images")
ZIP_OPTIONAL_DIRS = ("fonts", "locale")
MANIFEST = "manifest"


def patch_theme(text: str, case: int) -> str:
    cfg = CASES[case]
    text = re.sub(
        r"(function ThemeHomeLayout\(\) as string\n    return )[^\n]+",
        rf"\1{cfg['home']}",
        text,
        count=1,
    )
    text = re.sub(
        r"(function ThemeHeaderStyle\(\) as string\n    return )[^\n]+",
        rf"\1{cfg['header']}",
        text,
        count=1,
    )
    text = re.sub(
        r"(function ThemeHeroBannerStyle\(\) as string\n    return )[^\n]+",
        rf"\1{cfg['hero']}",
        text,
        count=1,
    )
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
            if path.name == ".gitkeep" or path.name == ".DS_Store":
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


def build_case(case: int) -> Path:
    if case not in CASES:
        raise SystemExit(f"Unknown layout case {case}; use 1–6.")

    original = THEME.read_text(encoding="utf-8")
    cfg = CASES[case]
    dest = OUT_SHARE / f"{APP_NAME}_{cfg['slug']}.zip"

    print(f"==> Layout case {case}: {cfg['slug']}")
    print(f"    home={cfg['home']} header={cfg['header']} hero={cfg['hero']}")

    try:
        THEME.write_text(patch_theme(original, case), encoding="utf-8")
        subprocess.run(["make", "validate"], cwd=ROOT, check=True)
        zip_channel(dest)
    finally:
        THEME.write_text(original, encoding="utf-8")

    size_mb = dest.stat().st_size / (1024 * 1024)
    print(f"==> Built {dest} ({size_mb:.1f}M)")
    return dest


def main() -> None:
    if len(sys.argv) != 2:
        cases = ", ".join(str(n) for n in sorted(CASES))
        raise SystemExit(f"Usage: {sys.argv[0]} <case 1-6|all>\nCases: {cases}")

    arg = sys.argv[1].strip().lower()
    if arg == "all":
        for case in sorted(CASES):
            build_case(case)
        return

    build_case(int(arg))


if __name__ == "__main__":
    main()
