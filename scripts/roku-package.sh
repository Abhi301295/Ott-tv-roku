#!/usr/bin/env bash
# Build out/ott-tv-roku.zip (bsc validate + zip). Run from repo root or via make zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
make zip
