#!/usr/bin/env bash
# Build Debug and launch Arkboard.app on a Mac.
# This script cannot run on Linux Cloud Agent hosts — there is no Xcode.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export ARKBOARD_REPO_ROOT="$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Arkboard is a native macOS app."
  echo "Run ./scripts/run.sh on Riyu's Mac (Xcode 15+, XcodeGen)."
  echo "On Linux, verify the design pack and sources with:"
  echo "  python3 scripts/spec_check.py"
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. brew install xcodegen"
  exit 1
fi

xcodegen generate
xcodebuild -scheme Arkboard -configuration Debug \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' build
open "$ROOT/build/DerivedData/Build/Products/Debug/Arkboard.app"
echo "Launched Arkboard.app. Smoke: ./scripts/smoke.sh"
