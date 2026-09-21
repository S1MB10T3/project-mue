#!/usr/bin/env bash
# Add one or more images to the booted simulator's photo library so the
# in-app picker has something to choose. Usage: scripts/sim-add-photo.sh a.jpg b.png
set -euo pipefail
[ $# -gt 0 ] || { echo "usage: $0 image [image…]" >&2; exit 1; }
xcrun simctl addmedia booted "$@"
echo "Added $# file(s) to the simulator's photo library."
