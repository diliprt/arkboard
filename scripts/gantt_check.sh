#!/usr/bin/env bash
# Compile and run the pure Timeline/Gantt logic that ships in the app.
#
# TimelineModel.swift and Model/Enums.swift import Foundation only, so this runs anywhere a Swift
# toolchain exists — including Linux Cloud Agent hosts, where the rest of Arkboard cannot build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install a Swift toolchain (swift.org/download) or run on a Mac with Xcode."
  echo "The design-pack checks still run without it:  python3 scripts/spec_check.py"
  exit 127
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

swiftc -O \
  -o "$OUT/gantt-tests" \
  Sources/Arkboard/Model/Enums.swift \
  Sources/Arkboard/UI/Portfolio/TimelineModel.swift \
  scripts/gantt-tests/main.swift

TZ=UTC "$OUT/gantt-tests"
