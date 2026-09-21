#!/usr/bin/env bash
# Build the app for the iOS Simulator. Prints only warnings and errors.
# Regenerates the Xcode project first so project.yml is always the source of truth.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build \
  -project Mue.xcodeproj \
  -scheme Mue \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
echo "BUILD SUCCEEDED"
