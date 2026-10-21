#!/bin/bash
# Turn sweep screenshots into menu thumbnails: center crop (drops the status bar and the debug
# label), downscale, JPEG. Usage: scripts/make-thumbs.sh <sweep-dir>... (later dirs win)
set -euo pipefail
source "$(dirname "$0")/env.sh"
OUT="$ROOT/app/entry/src/main/resources/rawfile/thumbs"
mkdir -p "$OUT"
for dir in "$@"; do
  awk -F'\t' '$2=="OK"{print $1}' "$dir/summary.tsv" | while read -r fx; do
    [ -f "$dir/$fx.jpeg" ] || continue
    sips -c 1800 1140 "$dir/$fx.jpeg" --out /tmp/thumb_$$.jpeg >/dev/null
    sips -Z 360 -s format jpeg -s formatOptions 72 /tmp/thumb_$$.jpeg --out "$OUT/$fx.jpg" >/dev/null
  done
done
rm -f /tmp/thumb_$$.jpeg
ls "$OUT" | wc -l
