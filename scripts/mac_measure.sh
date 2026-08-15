#!/usr/bin/env bash
# Measure a running Arkboard Debug build, then hand the numbers to Critique.
#
#     ./scripts/mac_measure.sh
#
# Compiles scripts/mac_measure.swift and runs it. Nothing else: no build of the
# app, no Xcode, no worktrees, no shot set. Arkboard must already be running.
#
# Exit codes are the measure tool's own:
#   0  every gate passed — paste the JSON into the Critique packet
#   1  a gate failed — the numbers drifted, fix before asking for a review
#   2  could not measure — app not running, or a permission is missing
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "These are Mac measures. Run this on Riyu's Mac."
  echo "On Linux the design-pack checks are what you have:  python3 scripts/spec_check.py"
  exit 2
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install the Xcode command line tools."
  exit 2
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

if ! swiftc -O -o "$OUT/arkboard-measure" scripts/mac_measure.swift; then
  echo "Could not compile scripts/mac_measure.swift."
  exit 2
fi

"$OUT/arkboard-measure"
status=$?

case "$status" in
  0) echo "Measures pass. Paste the JSON above into the Critique packet." ;;
  1) echo "Measures failed. This is not ready for Critique — a still cannot answer these." ;;
  2) echo "Nothing was measured, so nothing passed." ;;
esac
exit "$status"
