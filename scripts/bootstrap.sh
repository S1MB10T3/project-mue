#!/usr/bin/env bash
# One-time setup on a Mac: XcodeGen, local signing config, project generation.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen…"
  brew install xcodegen
fi

if [ ! -f Config/Local.xcconfig ]; then
  cp Config/Local.xcconfig.example Config/Local.xcconfig
  echo "Created Config/Local.xcconfig — edit MUE_BUNDLE_ID and MUE_TEAM_ID before building for a device."
fi

xcodegen generate
echo "Done. Open Mue.xcodeproj, or use scripts/sim-run.sh."
