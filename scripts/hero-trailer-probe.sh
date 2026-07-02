#!/usr/bin/env bash
# hero-trailer-probe.sh — HTTP evidence for hero trailer URL shapes (all 5 slides).
# Run from repo root. Does not need a logged-in session for S3 HEAD probes.

set -euo pipefail

BASE="https://ottacceleratordev.s3.us-east-1.amazonaws.com/private"
API="https://ottacceleratordev.appskeeper.in"
AUTH=$(printf '%s' 'OTT_USR:OTT_PWD' | base64 -w0)

echo "=== signed-cookies API (parity App.tsx getCookies) ==="
curl -s -D - -o /dev/null -H "Authorization: Basic $AUTH" -H "domain-name: ott-accelerator" -H "Platform: 4" \
  "$API/media/signed-cookies?key=private/movies/*" 2>&1 | grep -iE '^(HTTP|set-cookie:)' | head -6

slides=(
  "Gullak|movies|CON-BROUTIJ239/video_17796939667"
  "God-tussi|series|CON-2XCKTIPYW7/video_17730581921"
  "Ginny|movies|CON-P2N69ZLSH5/video_17821338676"
  "Hello-Mini|movies|CON-Y3EAAU4O2G/video_17709761782"
  "Lost|movies|CON-98LUACJLVU/video_17731421902"
)

echo ""
echo "=== banner trailer.url HEAD (unsigned curl) ==="
for row in "${slides[@]}"; do
  IFS='|' read -r name kind path <<<"$row"
  manifest="$BASE/$kind/$path"
  mp4="${manifest}31.mp4"
  mcode=$(curl -sI "$manifest" | head -1)
  pcode=$(curl -sI "$mp4" | head -1)
  printf "%-12s manifest: %s\n" "$name" "$mcode"
  printf "%-12s +31.mp4:  %s\n" "" "$pcode"
done

echo ""
echo "Ginny public mp4 (React network .mp4 segment pattern):"
echo "  ${BASE}/movies/CON-P2N69ZLSH5/video_1782133867631.mp4"
