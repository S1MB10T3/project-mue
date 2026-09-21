#!/usr/bin/env bash
# Build, install and launch the app in an iOS Simulator, streaming its console.
# Ctrl-C stops the stream (the app keeps running in the simulator).
#
#   scripts/sim-run.sh                 # first available iPhone simulator
#   MUE_SIM="iPhone 17 Pro" scripts/sim-run.sh
set -euo pipefail
cd "$(dirname "$0")/.."

sim_id="$(scripts/sim-id.sh)"
xcrun simctl boot "$sim_id" 2>/dev/null || true
open -a Simulator

xcodegen generate --quiet
xcodebuild build \
  -project Mue.xcodeproj \
  -scheme Mue \
  -configuration Debug \
  -destination "id=$sim_id" \
  -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

app="build/DerivedData/Build/Products/Debug-iphonesimulator/MUE.app"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"

xcrun simctl install "$sim_id" "$app"
xcrun simctl terminate "$sim_id" "$bundle_id" 2>/dev/null || true
echo "Launching $bundle_id on $sim_id (console follows, Ctrl-C to stop)…"
xcrun simctl launch --console-pty "$sim_id" "$bundle_id"
