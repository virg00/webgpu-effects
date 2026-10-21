#!/bin/bash
# Build the demo HAP (signed when app/build-profile.json5 has a signingConfig, unsigned otherwise).
set -euo pipefail
source "$(dirname "$0")/env.sh"
MODE="${1:-debug}"
PRODUCT="${PRODUCT:-default}"   # PRODUCT=devtest builds the signed variant for real phones
cd "$ROOT/app"
[ -d oh_modules ] || ohpm install >/dev/null
if [ "$PRODUCT" != default ]; then
  # Local-only products and signing (app/signing.local.json, not in git) are merged in for this build.
  [ -f signing.local.json ] || { echo "app/signing.local.json missing (see docs/signing.md)"; exit 1; }
  cp build-profile.json5 build-profile.json5.orig
  trap 'mv "$ROOT/app/build-profile.json5.orig" "$ROOT/app/build-profile.json5"' EXIT
  python3 -I - <<PY
import json
d = json.load(open('build-profile.json5'))
local = json.load(open('signing.local.json'))
d['app']['signingConfigs'] = local['signingConfigs']
d['app']['products'] += local['products']
names = [p['name'] for p in d['app']['products']]
for m in d['modules']:
    for t in m.get('targets', []):
        if 'applyToProducts' in t:
            t['applyToProducts'] = names
json.dump(d, open('build-profile.json5', 'w'), indent=2)
PY
fi
hvigorw --mode module -p product="$PRODUCT" -p module=entry@default -p buildMode="$MODE" assembleHap --no-daemon 2>&1 | grep -v "^\s*$"
ls -la "$ROOT/app/entry/build/$PRODUCT/outputs/default/"*.hap
