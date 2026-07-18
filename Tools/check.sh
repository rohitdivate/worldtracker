#!/usr/bin/env bash
# Pre-commit gate. Runs everything that can run on Linux:
#   1. WorldTrackerKit unit tests (real logic: geocoder, day math, resolver, clustering)
#   2. Syntax-parse every app Swift file (catches typos; not a type check)
#   3. Project/plist/asset invariants
#   4. Geodata golden checks (once M1 lands)
# The authoritative iOS compile check is .github/workflows/ios-build.yml (macOS).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

SWIFT_BIN="${SWIFT_BIN:-$(command -v swift || true)}"

echo "== 1/4 WorldTrackerKit tests"
if [ -n "$SWIFT_BIN" ]; then
  if ! "$SWIFT_BIN" test --package-path "$ROOT/WorldTrackerKit"; then
    FAIL=1
  fi
else
  echo "   swift not found — SKIPPED (CI will run this)"
fi

echo "== 2/4 swiftc -parse app sources"
SWIFTC_BIN="${SWIFTC_BIN:-$(command -v swiftc || true)}"
if [ -n "$SWIFTC_BIN" ]; then
  # -parse checks syntax only; imports of iOS-only frameworks are fine.
  FILES=$(find "$ROOT/WorldTracker" "$ROOT/BeenThereWidgets" -name '*.swift')
  if ! "$SWIFTC_BIN" -parse $FILES 2>&1 | grep -v "^$" | sed 's/^/   /'; then
    true
  fi
  if ! "$SWIFTC_BIN" -parse $FILES >/dev/null 2>&1; then
    echo "   PARSE ERRORS above"
    FAIL=1
  else
    echo "   ok ($(echo "$FILES" | wc -l | tr -d ' ') files)"
  fi
else
  echo "   swiftc not found — SKIPPED (CI will run this)"
fi

echo "== 3/4 project invariants"
if ! python3 "$ROOT/Tools/validate_project.py"; then
  FAIL=1
fi

echo "== 4/4 geodata golden checks"
if [ -f "$ROOT/Tools/geodata/golden_check.py" ]; then
  if ! python3 "$ROOT/Tools/geodata/golden_check.py"; then
    FAIL=1
  fi
else
  echo "   not present yet (lands in M1) — SKIPPED"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "CHECK FAILED"
  exit 1
fi
echo "ALL CHECKS PASSED"
