#!/bin/bash
# Benchmark every effect both ports share on $HDC_TARGET: each side alone, full screen, through the
# CompareDetail page's bench mode. Writes <outdir>/bench.jsonl (one SHADERBENCH line per run, plus
# the app's PSS memory) and screenshots <outdir>/<Effect>-<mode>.jpeg.
# TOUCH=1 keeps a finger moving during the measurement: LTPO screens then run at 120 Hz.
# Usage: PRODUCT=devtest HDC_TARGET=<phone> [TOUCH=1] scripts/compare-bench.sh <outdir> [Effect ...]
source "$(dirname "$0")/env.sh"
OUTDIR="$1"; shift
mkdir -p "$OUTDIR"
if [ $# -gt 0 ]; then NAMES="$*"; else
  NAMES=$(python3 -I -c "
import json,glob
for f in sorted(glob.glob('$ROOT/app/shaderport/src/main/resources/rawfile/effects/*/spec.json')): print(json.load(open(f))['name'])")
fi
: > "$OUTDIR/bench.jsonl"
for fx in $NAMES; do
  for mode in claude port; do
    hdc -t "$TARGET" shell aa force-stop "$BUNDLE" >/dev/null 2>&1
    hdc -t "$TARGET" shell "hilog -r" >/dev/null 2>&1
    hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE" --ps page CompareDetail --ps fx "$fx" --ps mode "$mode" >/dev/null
    if [ -n "${TOUCH:-}" ]; then
      # Cover the page's sampling window (2.5 s – 7.5 s after launch) with finger movement.
      sleep 1.5
      for k in 1 2 3; do
        hdc -t "$TARGET" shell uitest uiInput swipe 200 700 900 1700 600 >/dev/null
        hdc -t "$TARGET" shell uitest uiInput swipe 900 1700 200 700 600 >/dev/null
      done
    else
      sleep 6
    fi
    pid=$(hdc -t "$TARGET" shell pidof "$BUNDLE" | tr -d '\r')
    pss=$(hdc -t "$TARGET" shell "hidumper --mem $pid" 2>/dev/null | awk '$1=="Total" && $2 ~ /^[0-9]+$/ {print $2; exit}')
    "$(dirname "$0")/shot.sh" "$OUTDIR/$fx-$mode.jpeg" >/dev/null 2>&1
    sleep 3
    line=$(hdc -t "$TARGET" shell "hilog -x" | grep -o 'SHADERBENCH {.*}' | tail -1 | sed 's/^SHADERBENCH //')
    [ -z "$line" ] && line="{\"name\":\"$fx\",\"mode\":\"$mode\",\"missing\":true}"
    echo "{\"pssKb\":${pss:-0},\"run\":$line}" >> "$OUTDIR/bench.jsonl"
    echo "$fx $mode pss=${pss:-?} $(echo "$line" | cut -c1-160)"
  done
done
