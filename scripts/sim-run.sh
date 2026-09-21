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

# Bring up the Simulator window if the GUI app is installed. It normally lives
# inside Xcode, but some installs (Xcode 27) don't ship it at all — simctl
# drives the runtime either way, so never fail the run over a missing window.
sim_app="$(xcode-select -p)/Applications/Simulator.app"
if [ -d "$sim_app" ]; then
  open "$sim_app" || true
elif ! open -b com.apple.iphonesimulator 2>/dev/null; then
  echo "note: Simulator.app not installed; running headless." >&2
  echo "      Use scripts/sim-screenshot.sh to see the screen." >&2
fi

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
