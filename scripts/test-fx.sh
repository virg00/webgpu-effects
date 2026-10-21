#!/bin/bash
# Launch the debug Test page with one effect (or the default gradient), then save a screenshot and
# the app's logs. Usage: scripts/test-fx.sh [EffectName] [outdir] [seconds]
source "$(dirname "$0")/env.sh"
FX="${1:-}"; OUTDIR="${2:-$ROOT/build/fx}"; WAIT="${3:-6}"
mkdir -p "$OUTDIR"
name="${FX:-default}"
hdc -t "$TARGET" shell aa force-stop "$BUNDLE" >/dev/null 2>&1
hdc -t "$TARGET" shell "hilog -r" >/dev/null 2>&1
if [ -n "$FX" ]; then
  hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE" --ps page Test --ps fx "$FX" >/dev/null
else
  hdc -t "$TARGET" shell aa start -a EntryAbility -b "$BUNDLE" --ps page Test >/dev/null
fi
sleep 1
pid0=$(hdc -t "$TARGET" shell pidof "$BUNDLE" 2>/dev/null | tr -d '\r')
if [ -n "${SWIPE:-}" ]; then
  # Interactive effects only show something under a finger: draw a few strokes, then let it settle.
  sleep 2
  for stroke in "200 700 900 1500" "900 600 250 1700" "300 1900 950 900" "550 500 600 2000"; do
    set -- $stroke
    hdc -t "$TARGET" shell uitest uiInput swipe "$1" "$2" "$3" "$4" 1500 >/dev/null 2>&1
  done
  sleep 1
else
  sleep "$WAIT"
fi
# Everything the app process logged, plus crash reports that name it.
hdc -t "$TARGET" shell "hilog -x" 2>/dev/null | grep -E "^[0-9-]+ [0-9:.]+ +${pid0:-NOPID} |JsError|CppCrash|$BUNDLE.*(crash|Crash|died)" \
  | grep -vE "ownlevel|COMPUTE_SHADERS|shader_model|: +\),$|: }$" > "$OUTDIR/$name.log"
"$(dirname "$0")/shot.sh" "$OUTDIR/$name.jpeg" >/dev/null 2>&1 || echo "screenshot failed (device gone?)"
alive=$(hdc -t "$TARGET" shell pidof "$BUNDLE" 2>/dev/null | tr -d '\r')
errs=$(grep -cE "uncaptured|render error|renderer stopped|panic|createShader failed|requestDevice failed" "$OUTDIR/$name.log")
echo "$name pid=${alive:-DEAD} errors=$errs"
