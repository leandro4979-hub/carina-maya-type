#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLISTS=(
  "$ROOT/Apps/CarinaType/PocketTypeKeyboard/Info.plist"
  "$ROOT/Apps/MayaType/PocketTypeKeyboard/Info.plist"
)

for plist in "${PLISTS[@]}"; do
  value="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:RequestsOpenAccess' "$plist" 2>/dev/null || true)"
  if [[ "$value" != "false" ]]; then
    echo "Privacy check failed: RequestsOpenAccess must be false in $plist" >&2
    exit 1
  fi
done

if rg -n 'import (Network|WebKit)|URLSession|NWConnection|Analytics|Telemetry' \
  "$ROOT/Apps/CarinaType/PocketTypeKeyboard" \
  "$ROOT/Apps/MayaType/PocketTypeKeyboard"; then
  echo "Privacy check failed: review networking or telemetry usage in keyboard sources." >&2
  exit 1
fi

echo "Privacy checks passed: both keyboards keep Full Access disabled and contain no recognized network or telemetry APIs."
