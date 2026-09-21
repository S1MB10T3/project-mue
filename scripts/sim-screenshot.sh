#!/usr/bin/env bash
# Screenshot the booted simulator. Usage: scripts/sim-screenshot.sh [out.png]
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-build/screenshot.png}"
mkdir -p "$(dirname "$out")"
xcrun simctl io booted screenshot "$out" >/dev/null
echo "$out"
