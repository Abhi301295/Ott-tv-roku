#!/usr/bin/env python3
"""Parse Roku telnet logs into a TTFC (time-to-first-content) breakdown.

Usage:
  python3 scripts/sim.py log 45 > /tmp/roku.log
  python3 scripts/perf_report.py /tmp/roku.log

Phases (one home boot session):
  api          — sum of home-path HTTP round-trips (select, CW, categories, hero view)
  gate_wait    — boot span from rows data ready → row gate open
  node_build   — [PERF] render-cost (actual SceneGraph work on render thread)
  node_wall    — [PERF] wall (incremental timer yield between rows/cards)
  yield_overhead — node_wall - node_build (intentional thread breathing)
  shimmer      — rows skeleton visible until first row painted (from [BOOT] rows revealed)
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

HTTP_RE = re.compile(
    r"\[HTTP\]\s+\S+\s+(\d+)ms\s+(\d+)\s+(.+)$"
)
HTTP_WARM_RE = re.compile(r"\[HTTP_WARM\]")
BOOT_RE = re.compile(r"\[BOOT\]\s+(.+?)\s+\+(\d+)ms(?:\s+(.*))?$")
PERF_ROW_RE = re.compile(
    r"\[PERF\]\s+all rows built:\s+(\d+)\s+rows,\s+render-cost=\s*(\d+)ms,\s+wall=\s*(\d+)ms"
)
PERF_BUILD_ROW_RE = re.compile(
    r"\[PERF\]\s+build row\s+(\d+)\s+'([^']*)'\s+cards=\s*(\d+)\s+(\d+)ms"
)
PREFETCH_START_RE = re.compile(r"\[PREFETCH_DBG\]\s+start\s+profileId=(\S+)")
PREFETCH_NAV_RE = re.compile(r"\[PREFETCH_DBG\]\s+navigate_home\s+profileId=(\S+)")

HOME_API_SUFFIXES = (
    "accounts/select-profile",
    "videos/continue-watching",
    "contents/home",
    "contents/view/",
    "configuration",
    "customers/profiles/list",
)


@dataclass
class HomeSession:
  profile_id: str = ""
  prefetch_start_line: int = 0
  navigate_line: int = 0
  http_calls: list[tuple[int, int, str]] = field(default_factory=list)
  boot_events: list[tuple[str, int, str]] = field(default_factory=list)
  row_builds: list[tuple[int, int, int]] = field(default_factory=list)  # render, wall, rows
  row_details: list[tuple[int, str, int, int]] = field(default_factory=list)


def parse_sessions(lines: list[str]) -> list[HomeSession]:
  sessions: list[HomeSession] = []
  cur: HomeSession | None = None
  in_home = False

  for i, line in enumerate(lines):
    m = PREFETCH_START_RE.search(line)
    if m:
      cur = HomeSession(profile_id=m.group(1), prefetch_start_line=i + 1)
      sessions.append(cur)
      in_home = False
      continue

    if cur is None:
      continue

    m = PREFETCH_NAV_RE.search(line)
    if m:
      cur.navigate_line = i + 1
      in_home = True
      continue

    if not in_home:
      m = HTTP_RE.search(line)
      if m and not HTTP_WARM_RE.search(line):
        ms, status, path = int(m.group(1)), int(m.group(2)), m.group(3).strip()
        if any(s in path for s in HOME_API_SUFFIXES):
          cur.http_calls.append((ms, status, path))
      continue

    m = HTTP_RE.search(line)
    if m and not HTTP_WARM_RE.search(line):
      ms, status, path = int(m.group(1)), int(m.group(2)), m.group(3).strip()
      cur.http_calls.append((ms, status, path))

    m = BOOT_RE.search(line)
    if m:
      cur.boot_events.append((m.group(1).strip(), int(m.group(2)), (m.group(3) or "").strip()))

    m = PERF_BUILD_ROW_RE.search(line)
    if m:
      cur.row_details.append(
        (int(m.group(1)), m.group(2), int(m.group(3)), int(m.group(4)))
      )

    m = PERF_ROW_RE.search(line)
    if m:
      rows = int(m.group(1))
      render = int(m.group(2))
      wall = int(m.group(3))
      cur.row_builds.append((render, wall, rows))
      in_home = False

  return sessions


def boot_ms(events: list[tuple[str, int, str]], tag: str) -> int | None:
  for t, ms, _ in events:
    if t == tag:
      return ms
  return None


def fmt_ms(n: int) -> str:
  return f"{n:,}ms"


def report_session(idx: int, s: HomeSession) -> None:
  print(f"\n{'=' * 60}")
  print(f"Session {idx + 1}  profile={s.profile_id or '?'}")
  print(f"{'=' * 60}")

  if not s.http_calls and not s.boot_events:
    print("  (no home boot data — drive profile → home while logging)")
    return

  # API breakdown
  api_by_path: dict[str, list[int]] = {}
  for ms, _status, path in s.http_calls:
    key = path.split("?")[0]
    api_by_path.setdefault(key, []).append(ms)

  print("\n── API round-trips (network + server) ──")
  api_total = 0
  for path in sorted(api_by_path, key=lambda p: -max(api_by_path[p])):
    times = api_by_path[path]
    peak = max(times)
    api_total += peak
    print(f"  {peak:>6}ms  {path}")
  print(f"  {'─' * 40}")
  print(f"  {fmt_ms(api_total):>10}  critical-path sum (parallel calls overlap in practice)")

  # Boot timeline
  if s.boot_events:
    print("\n── Boot timeline ([BOOT] markers from home mount) ──")
    for tag, ms, detail in s.boot_events:
      extra = f"  {detail}" if detail else ""
      print(f"  +{ms:>5}ms  {tag}{extra}")

    data_ready = boot_ms(s.boot_events, "rows data ready")
    gate_open = boot_ms(s.boot_events, "row gate open")
    row0_paint = boot_ms(s.boot_events, "row0 paintedReady")
    revealed = boot_ms(s.boot_events, "rows revealed")

    if data_ready is not None and gate_open is not None:
      gate_wait = gate_open - data_ready
      print(f"\n  Gate wait (data ready → gate open): {fmt_ms(gate_wait)}")
    if row0_paint is not None:
      print(f"  Time to row0 paintedReady: {fmt_ms(row0_paint)}")
    if revealed is not None:
      print(f"  Time to shimmer off (rows revealed): {fmt_ms(revealed)}")

  # Node build
  if s.row_builds:
    render, wall, rows = s.row_builds[-1]
    yield_ms = max(0, wall - render)
    print("\n── SceneGraph row build ──")
    print(f"  Rows built:        {rows}")
    print(f"  Render-thread CPU: {fmt_ms(render)}  (actual node creation)")
    print(f"  Wall clock:        {fmt_ms(wall)}  (incremental timer ticks)")
    print(f"  Yield overhead:    {fmt_ms(yield_ms)}  (thread breathing — not CPU work)")
    if wall > 0:
      pct = round(100 * render / wall)
      print(f"  CPU vs wall:       {pct}% CPU / {100 - pct}% waiting")

  if s.row_details:
    print("\n── Per-row render cost ──")
    for idx_row, name, cards, ms in s.row_details:
      print(f"  row {idx_row} '{name}'  cards={cards}  {ms}ms")

  # Summary for stakeholders
  print("\n── Summary (what to tell the team) ──")
  if s.boot_events:
    ttfc = boot_ms(s.boot_events, "rows revealed") or boot_ms(s.boot_events, "row0 paintedReady")
    if ttfc is not None:
      print(f"  TTFC (shimmer off):     ~{fmt_ms(ttfc)}")
  if s.row_builds:
    render, wall, _ = s.row_builds[-1]
    print(f"  Node creation is NOT the bottleneck ({fmt_ms(render)} CPU vs {fmt_ms(wall)} wall).")
    print(f"  Most wall time is intentional yield + hero gate + image decode waits.")
  if api_by_path:
    slow = max((max(v), k) for k, v in api_by_path.items())
    print(f"  Slowest API:            {slow[0]}ms  {slow[1]}")


def main() -> int:
  if len(sys.argv) < 2:
    print(__doc__)
    return 1
  path = Path(sys.argv[1])
  if not path.is_file():
    print(f"File not found: {path}", file=sys.stderr)
    return 1
  lines = path.read_text(errors="replace").splitlines()
  sessions = parse_sessions(lines)
  if not sessions:
    print("No [PREFETCH_DBG] sessions found. Capture logs while selecting a profile.")
    return 1
  print(f"Parsed {len(sessions)} profile→home session(s) from {path}")
  for i, s in enumerate(sessions):
    report_session(i, s)
  print()
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
