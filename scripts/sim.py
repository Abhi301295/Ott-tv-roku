#!/usr/bin/env python3
"""
sim.py — drive the local BrightScript Simulator (brs-desktop) autonomously.

The simulator exposes a Roku-style ECP server on :8060 (no auth) for remote
keypresses and a telnet debug console on :8085 for BrightScript `print` output.
Screenshots are taken with `gnome-screenshot -w` (the sim is an Electron window
on Wayland, so X11 tools like xdotool don't work) and cropped to the channel
render area.

Usage:
  scripts/sim.py key Up Right Select          # send ECP keypresses (Roku key names)
  scripts/sim.py text "hello"                  # type literal characters
  scripts/sim.py shot [out.png]                # screenshot -> crop channel (default /tmp/sim_shot.png)
  scripts/sim.py log [seconds]                 # capture telnet console output (default 6s)
  scripts/sim.py info                          # ECP device-info

Key names: Up Down Left Right Select Back Home Play Rev Fwd InstantReplay Info Backspace Enter
"""
import sys
import time
import socket
import subprocess
import urllib.request
import urllib.parse

HOST = "127.0.0.1"
ECP = f"http://{HOST}:8060"
TELNET_PORT = 8085
PURPLE = (61, 27, 86)


def ecp_post(path):
    req = urllib.request.Request(f"{ECP}/{path}", data=b"", method="POST")
    with urllib.request.urlopen(req, timeout=5) as r:
        return r.status


def ecp_get(path):
    with urllib.request.urlopen(f"{ECP}/{path}", timeout=5) as r:
        return r.read().decode("utf-8", "replace")


def cmd_key(keys):
    for k in keys:
        code = ecp_post(f"keypress/{k}")
        print(f"key {k} -> {code}")
        time.sleep(0.45)


def cmd_text(s):
    for ch in s:
        ecp_post(f"keypress/Lit_{urllib.parse.quote(ch)}")
        time.sleep(0.12)
    print(f"typed: {s}")


def _frac(row_or_col, pred, step=7):
    n = sum(1 for c in row_or_col if pred(c))
    total = len(range(0, len(row_or_col), 1))
    return n / max(1, total)


def cmd_shot(out):
    # Full-screen capture (focus-independent), then locate the brs-desktop window by
    # its purple title/menu bar so we don't depend on the sim being the active window.
    raw = "/tmp/_sim_full.png"
    subprocess.run(["gnome-screenshot", "-f", raw], check=True)
    from PIL import Image
    im = Image.open(raw).convert("RGB")
    W, H = im.size
    px = im.load()

    def is_purple(c, tol=22):
        return all(abs(c[i] - PURPLE[i]) <= tol for i in range(3))

    def is_black(c, t=16):
        return c[0] < t and c[1] < t and c[2] < t

    # Longest contiguous run of purple in a row -> (length, start, end).
    def purple_run(y):
        best = (0, 0, 0); cur = 0; start = 0
        for x in range(0, W):
            if is_purple(px[x, y]):
                if cur == 0:
                    start = x
                cur += 1
                if cur > best[0]:
                    best = (cur, start, x)
            else:
                cur = 0
        return best

    # Find the simulator's purple chrome: the top-most band of rows with a long
    # purple run. That run's x-extent is the window width; its bottom is channel top.
    MINRUN = max(250, W // 6)
    band_rows = []
    win_l, win_r = None, None
    for y in range(0, H):
        run = purple_run(y)
        if run[0] >= MINRUN:
            band_rows.append(y)
            if win_l is None or run[1] < win_l:
                win_l = run[1]
            if win_r is None or run[2] > win_r:
                win_r = run[2]
        elif band_rows:
            # band ended
            break
    if not band_rows:
        print("WARN: brs-desktop purple chrome not found on screen — is the simulator "
              "window visible (not minimized/covered)?", file=sys.stderr)
        im.save(out)
        return
    channel_top = band_rows[-1] + 1
    left, right = win_l, win_r

    def in_x(x):
        return left <= x <= right

    # Bottom: the status bar is a solid low-variance band at the window bottom.
    def row_is_solid_bar(y):
        s = range(left, right, 9)
        cols = [px[x, y] for x in s]
        rs = [c[0] for c in cols]; gs = [c[1] for c in cols]; bs = [c[2] for c in cols]
        spread = (max(rs)-min(rs)) + (max(gs)-min(gs)) + (max(bs)-min(bs))
        avg = (sum(rs) + sum(gs) + sum(bs)) / (3 * len(cols))
        return avg > 35 and spread < 230
    # window bottom = first non-purple-band region's end; scan down until we leave
    # the channel (a long stretch of non-sim content). Use the status bar as anchor.
    bottom = H - 1
    # find the channel's bottom by walking up from the lowest plausible window row
    # (status bar). Search the lower part of the screen for the solid status bar.
    sb = None
    for y in range(min(H - 1, channel_top + 1200), channel_top, -1):
        if y < H and row_is_solid_bar(y) and row_is_solid_bar(max(channel_top, y - 2)):
            sb = y
            break
    if sb is not None:
        # walk up over the whole status-bar band
        b = sb
        while b > channel_top and row_is_solid_bar(b):
            b -= 1
        bottom = b
    else:
        bottom = min(H - 1, channel_top + (right - left) * 9 // 16)

    # Trim black letterbox pillars within the window x-range (measure clean mid band).
    y0 = channel_top + max(10, (bottom - channel_top) // 8)
    y1 = bottom - max(10, (bottom - channel_top) // 8)
    def col_black_frac(x):
        s = range(y0, y1, 9)
        return sum(1 for y in s if is_black(px[x, y])) / max(1, len(s))
    L = left
    for x in range(left, right + 1):
        if col_black_frac(x) < 0.9:
            L = x; break
    R = right
    for x in range(right, left - 1, -1):
        if col_black_frac(x) < 0.9:
            R = x; break

    crop = im.crop((L, channel_top, R + 1, bottom + 1))
    crop.save(out)
    print(f"saved {out} {crop.size}  (window x[{left},{right}] channel rect L{L} T{channel_top} R{R} B{bottom})")


def cmd_log(seconds):
    s = socket.create_connection((HOST, TELNET_PORT), timeout=5)
    s.settimeout(1.0)
    end = time.time() + seconds
    buf = b""
    while time.time() < end:
        try:
            data = s.recv(4096)
            if not data:
                break
            buf += data
            sys.stdout.write(data.decode("utf-8", "replace"))
            sys.stdout.flush()
        except socket.timeout:
            pass
    s.close()


def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    cmd = sys.argv[1]
    if cmd == "key":
        cmd_key(sys.argv[2:])
    elif cmd == "text":
        cmd_text(" ".join(sys.argv[2:]))
    elif cmd == "shot":
        cmd_shot(sys.argv[2] if len(sys.argv) > 2 else "/tmp/sim_shot.png")
    elif cmd == "log":
        cmd_log(int(sys.argv[2]) if len(sys.argv) > 2 else 6)
    elif cmd == "info":
        print(ecp_get("query/device-info"))
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
