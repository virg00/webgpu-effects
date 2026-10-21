#!/bin/bash
# Print the latest native crash of this app on $HDC_TARGET with libwebgpu_effects.so frames symbolized.
source "$(dirname "$0")/env.sh"
f=$(hdc -t "$TARGET" shell "ls -t /data/log/faultlog/faultlogger/ | grep $BUNDLE | head -1" | tr -d '\r')
log=$(hdc -t "$TARGET" shell "cat /data/log/faultlog/faultlogger/$f")
abi=$(echo "$log" | sed -n 's/^CpuAbi:\(.*\)/\1/p' | tr -d '\r')
so=$(find "$ROOT/app/webgpu-effects/build" -path "*intermediates/libs*${abi:-arm64-v8a}*" -name libwebgpu_effects.so | head -1)
echo "$log" | sed -n '/^Reason/,/^Registers\|^Other thread/p' | head -${1:-45} | while IFS= read -r line; do
  if [[ "$line" =~ pc\ ([0-9a-f]+)\ .*libwebgpu_effects\.so ]]; then
    sym=$("$OHOS_NDK/llvm/bin/llvm-addr2line" -f -C -e "$so" "0x${BASH_REMATCH[1]}" | paste -sd' ' -)
    echo "$line  => $sym" | cut -c1-260
  else
    echo "$line" | cut -c1-200
  fi
done
