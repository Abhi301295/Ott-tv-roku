#!/usr/bin/env bash
# smoke.sh — Phase F simulator smoke (make validate + deploy + telnet assertions).
#
# Usage (from repo root):
#   scripts/smoke.sh              # validate, deploy, drive keys, grep log
#   SMOKE_DEPLOY=0 scripts/smoke.sh   # skip make sim (channel already running)
#   SMOKE_LOG_SECS=45 scripts/smoke.sh
#
# Requires: brs-desktop running (ECP :8060, telnet :8085).
# Log tags: [HTTP] always; [HOME]/[PERF] when home boots; [OTT_DBG] only if OttDbgEnabled().

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG="${SMOKE_LOG:-/tmp/roku-smoke.log}"
DEPLOY="${SMOKE_DEPLOY:-1}"
LOG_SECS="${SMOKE_LOG_SECS:-35}"
FAIL=0

assert_grep() {
  local pattern="$1" min="$2" desc="$3"
  local count
  count=$(grep -cE "$pattern" "$LOG" 2>/dev/null || true)
  if [[ -z "$count" ]]; then count=0; fi
  if [[ "$count" -ge "$min" ]]; then
    echo "  OK   $desc ($count)"
  else
    echo "  FAIL $desc (need >=$min, got $count)"
    FAIL=1
  fi
}

assert_not_grep() {
  local pattern="$1" desc="$2"
  if grep -qE "$pattern" "$LOG" 2>/dev/null; then
    echo "  FAIL $desc (unexpected)"
    FAIL=1
  else
    echo "  OK   $desc (none)"
  fi
}

echo "==> [1/4] make validate"
make validate

if [[ "$DEPLOY" == "1" ]]; then
  echo "==> [2/4] make sim (deploy + relaunch)"
  make sim
  sleep 6
else
  echo "==> [2/4] skip deploy (SMOKE_DEPLOY=0)"
fi

echo "==> [3/4] ECP + telnet capture (${LOG_SECS}s)"
if ! python3 scripts/sim.py info >/dev/null 2>&1; then
  echo "FAIL: ECP not reachable on :8060 — start brs-desktop first."
  exit 1
fi

: >"$LOG"
python3 scripts/sim.py log "$LOG_SECS" >>"$LOG" 2>&1 &
LOG_PID=$!
sleep 3
# Light navigation while logs stream (home header / rows if booted past login).
python3 scripts/sim.py key Down Right Back Down Left Back 2>/dev/null || true
wait "$LOG_PID" 2>/dev/null || true

echo "==> [4/4] log assertions (see $LOG)"
assert_grep '\[HTTP\]' 1 'HTTP trace present'
assert_grep '\[HTTP\].*200' 1 'HTTP 200 response'
assert_not_grep 'BrightScript Micro Debugger' 'runtime crash'
assert_not_grep 'ERR_RULE_NOT_FOUND' 'missing component'
assert_not_grep 'Syntax error' 'syntax error'

# Home boot path (profile → home or cached session).
if grep -qE '\[HOME\]|\[HOME_BOOT_DBG\]' "$LOG" 2>/dev/null; then
  assert_grep '\[HOME\]|\[HOME_BOOT_DBG\]' 1 'home boot markers'
  if grep -q '\[PERF\] all rows built' "$LOG" 2>/dev/null; then
    assert_grep '\[PERF\] all rows built' 1 'home row build complete'
  fi
fi

# Profile prefetch path (cold boot through picker).
if grep -q '\[PREFETCH_DBG\]' "$LOG" 2>/dev/null; then
  assert_grep '\[PREFETCH_DBG\] navigate_home' 1 'profile prefetch navigate'
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo ""
  echo "SMOKE FAILED — tail of $LOG:"
  tail -50 "$LOG"
  exit 1
fi

echo ""
echo "SMOKE PASSED — full log: $LOG"
