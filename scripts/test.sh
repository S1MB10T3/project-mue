#!/usr/bin/env bash
# Run the MueCore unit tests. Extra arguments are passed to `swift test`,
# e.g. scripts/test.sh --filter SpectrogramAnalyzerTests
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --package-path MueCore "$@"
