#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ ! -d Arkboard.xcodeproj ]]; then
  xcodegen generate
fi
xcodebuild -scheme Arkboard -configuration Debug \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' build
open "$ROOT/build/DerivedData/Build/Products/Debug/Arkboard.app"
