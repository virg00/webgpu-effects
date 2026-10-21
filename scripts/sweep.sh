#!/bin/bash
# Run every effect from the catalog through scripts/test-fx.sh on $HDC_TARGET and write
# <outdir>/summary.tsv (name, status, error count, center pixel). On the emulator a crashed
# emulator is restarted and the sweep continues.
# Usage: scripts/sweep.sh <outdir> [Effect ...]
source "$(dirname "$0")/env.sh"
OUTDIR="$1"; shift
mkdir -p "$OUTDIR"
if [ $# -gt 0 ]; then NAMES="$*"; else
  NAMES=$(node -e "for (const e of require('$ROOT/app/entry/src/main/resources/rawfile/catalog.json')) console.log(e.name)")
fi
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator
restart_emulator() {
  (cd "$EMU" && (echo y | ./Emulator -start 'Pura 90' ${EMU_IMAGE_ROOT:+-imageRoot "$EMU_IMAGE_ROOT"} >/dev/null 2>&1 &))
  for i in $(seq 1 100); do
    [ "$(hdc -t "$TARGET" shell param get bootevent.boot.completed 2>/dev/null | tr -d '\r')" = "true" ] && break
    sleep 3
  done
  sleep 8
  hdc -t "$TARGET" shell "hilog -Q pidoff; hilog -Q domainoff" >/dev/null 2>&1
}
: > "$OUTDIR/summary.tsv"
wait_unlocked() {
  # Real phones: pause while the screen is locked (screenshots of the lock screen are useless).
  [[ "$TARGET" == 127.0.0.1* ]] && return
  local warned=0
  while hdc -t "$TARGET" shell "hidumper -s 3704 -a -all" 2>/dev/null | grep -qE "screenLocked[[:space:]]+true"; do
    [ $warned = 0 ] && echo "device locked — waiting" >&2 && warned=1
    sleep 10
  done
}
for fx in $NAMES; do
  wait_unlocked
  line=$("$(dirname "$0")/test-fx.sh" "$fx" "$OUTDIR" "${WAIT:-7}")
  if echo "$line" | grep -q "not found\|E001005"; then
    printf '%s\tDEVICE-CRASH\t-\t-\n' "$fx" >> "$OUTDIR/summary.tsv"
    [[ "$TARGET" == 127.0.0.1* ]] && restart_emulator
    continue
  fi
  pid=$(echo "$line" | sed -n 's/.*pid=\([^ ]*\).*/\1/p'); errs=$(echo "$line" | sed -n 's/.*errors=\([0-9]*\).*/\1/p')
  px=$(python3 -I "$(dirname "$0")/pixel.py" "$OUTDIR/$fx.jpeg" 2>/dev/null | sed -n 's/^center //p')
  status=OK; [ "$pid" = DEAD ] && status=APP-DIED; [ "${errs:-0}" -gt 0 ] && [ "$status" = OK ] && status=ERRORS
  printf '%s\t%s\t%s\t%s\n' "$fx" "$status" "$errs" "$px" >> "$OUTDIR/summary.tsv"
done
cut -f2 "$OUTDIR/summary.tsv" | sort | uniq -c
