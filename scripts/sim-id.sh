#!/usr/bin/env bash
# Print the UDID of the simulator to use: $MUE_SIM by name if set, otherwise
# the currently booted iPhone, otherwise the first available iPhone.
set -euo pipefail
list="$(xcrun simctl list devices available)"
if [ -n "${MUE_SIM:-}" ]; then
  line="$(echo "$list" | grep -F "    $MUE_SIM (" | head -n1 || true)"
else
  line="$(echo "$list" | grep -E '^\s+iPhone' | grep '(Booted)' | head -n1 || true)"
  [ -n "$line" ] || line="$(echo "$list" | grep -E '^\s+iPhone' | head -n1 || true)"
fi
id="$(echo "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1 || true)"
if [ -z "$id" ]; then
  echo "No matching iPhone simulator. Available:" >&2
  echo "$list" >&2
  exit 1
fi
echo "$id"
