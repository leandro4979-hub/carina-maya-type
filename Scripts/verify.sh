#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${TMPDIR:-/tmp}/carina-maya-type-derived-data"

"$ROOT/Scripts/verify-privacy.sh"

for app in CarinaType MayaType; do
  echo "Building $app..."
  xcodebuild \
    -project "$ROOT/Apps/$app/PocketType.xcodeproj" \
    -scheme PocketType \
    -sdk iphonesimulator \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA/$app" \
    -destination "generic/platform=iOS Simulator" \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    build
done

echo "Verification passed for CARINA TYPE and MAYA TYPE."
