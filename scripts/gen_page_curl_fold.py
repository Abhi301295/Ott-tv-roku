#!/usr/bin/env python3
"""Page-curl fold highlight — soft vertical shadow swept during flip."""
from PIL import Image

W, H = 200, 918
out = "/home/admin3329/Desktop/Roku-Tv-Final/ott-tv-roku/images/ui/page_curl_fold.png"
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pixels = img.load()
for x in range(W):
    t = x / max(W - 1, 1)
    # Dark crease at left edge of fold band, fading right
    a = int(220 * (1.0 - t) ** 1.6)
    for y in range(H):
        pixels[x, y] = (0, 0, 0, a)
img.save(out)
print("Wrote", out)
