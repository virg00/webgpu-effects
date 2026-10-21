#!/bin/bash
# Screenshot $HDC_TARGET (default: emulator) to the given path (default: shot.jpeg).
set -euo pipefail
source "$(dirname "$0")/env.sh"
OUTFILE="${1:-shot.jpeg}"
hdc -t "$TARGET" shell snapshot_display -f /data/local/tmp/shot.jpeg >/dev/null
hdc -t "$TARGET" file recv /data/local/tmp/shot.jpeg "$OUTFILE" >/dev/null
echo "$OUTFILE"
