#!/usr/bin/env bash
# Install out/ott-tv-roku.zip to the BrightScript Simulator dev slot and launch it.
#
# Manual fallback: Simulator → File → Open Channel Package → out/ott-tv-roku.zip
# Or browser: http://127.0.0.1:8080 → Install
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$ROOT/out/ott-tv-roku.zip"
HOST="${ROKU_SIM_HOST:-127.0.0.1}"
PORT="${ROKU_SIM_PORT:-8080}"
ECP="http://${HOST}:8060"
PASS="${ROKU_DEV_PASSWORD:-rokudev}"
DEV_ZIP="${HOME}/.config/BrightScript Simulator/dev.zip"

if [[ ! -f "$ZIP" ]]; then
  echo "==> Building package..."
  bash "$ROOT/scripts/roku-package.sh"
fi

echo "==> Zip: $ZIP ($(du -h "$ZIP" | cut -f1))"

echo "==> Home (exit foreground app)"
curl -sS -o /dev/null -X POST "$ECP/keypress/Home" 2>/dev/null || true
sleep 0.3

echo "==> Install dev slot (Digest auth)"
HTTP_CODE=$(curl -sS --digest -u "rokudev:${PASS}" \
  -F "mysubmit=Install" \
  -F "archive=@${ZIP}" \
  -w "%{http_code}" \
  -o /tmp/roku-install.html \
  "http://${HOST}:${PORT}/plugin_install" || echo "000")

INSTALL_OK=0
if [[ "$HTTP_CODE" == "200" ]]; then
  if grep -qE 'Application Received|Identical|Install Success' /tmp/roku-install.html 2>/dev/null; then
    INSTALL_OK=1
    echo "    HTTP 200 — install accepted"
  else
    echo "    HTTP 200 — check /tmp/roku-install.html"
    head -c 400 /tmp/roku-install.html | sed 's/^/    /'
  fi
else
  echo "    HTTP ${HTTP_CODE} — curl install failed"
  if [[ -d "$(dirname "$DEV_ZIP")" ]]; then
    cp -f "$ZIP" "$DEV_ZIP"
    echo "    Copied zip → $DEV_ZIP (relaunch dev channel)"
    INSTALL_OK=1
  fi
fi

if [[ "$INSTALL_OK" == "0" ]]; then
  echo "ERROR: Install failed. Use File → Open Channel Package → $ZIP" >&2
  exit 1
fi

echo "==> Launch dev"
curl -sS -o /dev/null -X POST "$ECP/launch/dev" 2>/dev/null || true
echo "Done. If the app does not appear, open Development → OTT Accelerator (dev)."
