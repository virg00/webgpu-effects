#!/bin/bash
# Install the built HAP on $HDC_TARGET (default: emulator) and start it.
set -euo pipefail
source "$(dirname "$0")/env.sh"
PRODUCT="${PRODUCT:-default}"
OUT="$ROOT/app/entry/build/$PRODUCT/outputs/default"
HAP="$OUT/entry-default-signed.hap"
[ -f "$HAP" ] || HAP="$OUT/entry-default-unsigned.hap"
hdc -t "$TARGET" shell aa force-stop "$BUNDLE" >/dev/null 2>&1 || true
out=$(hdc -t "$TARGET" install -r "$HAP" 2>&1); echo "$out"
if echo "$out" | grep -q "failed to install" && [ -f "$OUT/entry-default-unsigned.hap" ]; then
  hdc -t "$TARGET" install -r "$OUT/entry-default-unsigned.hap"
fi
hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE"
