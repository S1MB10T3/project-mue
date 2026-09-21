#!/usr/bin/env bash
# Build, install and launch the app on a connected iPhone, streaming its console.
# Needs Config/Local.xcconfig with your bundle id and team id.
#
#   scripts/device-run.sh                 # first connected device
#   MUE_DEVICE=<udid> scripts/device-run.sh
set -euo pipefail
cd "$(dirname "$0")/.."

device="${MUE_DEVICE:-}"
if [ -z "$device" ]; then
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null
  device="$(python3 - "$json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for d in data.get("result", {}).get("devices", []):
    props = d.get("deviceProperties", {})
    conn = d.get("connectionProperties", {})
    if conn.get("pairingState") == "paired" and conn.get("tunnelState") in ("connected", "connecting", "available"):
        print(d["identifier"]); break
PY
)"
  rm -f "$json"
fi
[ -n "$device" ] || { echo "No connected, paired iPhone found. Plug it in and unlock it." >&2; exit 1; }

xcodegen generate --quiet
xcodebuild build \
  -project Mue.xcodeproj \
  -scheme Mue \
  -configuration Debug \
  -destination "id=$device" \
  -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation -skipMacroValidation \
  -allowProvisioningUpdates \
  -quiet

app="build/DerivedData/Build/Products/Debug-iphoneos/MUE.app"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"
xcrun devicectl device install app --device "$device" "$app"
echo "Launching $bundle_id on $device (console follows, Ctrl-C to stop)…"
xcrun devicectl device process launch --console --device "$device" "$bundle_id"
