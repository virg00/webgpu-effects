#!/bin/bash
# Build the release HAR of @virgo/webgpu-effects (what `ohpm publish` uploads) into build/har/.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT/app"
[ -d oh_modules ] || ohpm install >/dev/null
# The HAR only ships README / CHANGELOG / LICENSE, so the package LICENSE carries the third-party notices too.
{ cat "$ROOT/LICENSE"; printf '\n\n'; cat "$ROOT/THIRD_PARTY_NOTICES.md"; } > webgpu-effects/LICENSE
hvigorw --mode module -p product=default -p module=webgpu_effects@default -p buildMode=release assembleHar --no-daemon 2>&1 | grep -v "^\s*$"
mkdir -p "$ROOT/build/har"
har=$(find webgpu-effects/build/default/outputs -name '*.har' | head -1)
cp "$har" "$ROOT/build/har/"
ls -la "$ROOT/build/har/"
