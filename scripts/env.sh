#!/bin/bash
ROOT="${SH_ROOT:-$HOME/shaders-harmony}"
DEVECO_ROOT="/Applications/DevEco-Studio.app/Contents"
export JAVA_HOME="$DEVECO_ROOT/jbr/Contents/Home"
export DEVECO_SDK_HOME="$DEVECO_ROOT/sdk"
export OHOS_NDK="$DEVECO_ROOT/sdk/default/openharmony/native"
export PATH="$DEVECO_ROOT/tools/node/bin:$DEVECO_ROOT/tools/ohpm/bin:$DEVECO_ROOT/tools/hvigor/bin:$DEVECO_ROOT/sdk/default/openharmony/toolchains:$HOME/.cargo/bin:$PATH"
TARGET="${HDC_TARGET:-127.0.0.1:5555}"
BUNDLE="$(sed -n 's/.*"bundleName": *"\([^"]*\)".*/\1/p' "$ROOT/app/AppScope/app.json5")"
# Local products (app/signing.local.json) may sign under another bundle name.
if [ "${PRODUCT:-default}" != default ] && [ -f "$ROOT/app/signing.local.json" ]; then
  B="$(python3 -I -c 'import json,sys; print(next((p.get("bundleName","") for p in json.load(open(sys.argv[1]))["products"] if p["name"]==sys.argv[2]),""))' "$ROOT/app/signing.local.json" "$PRODUCT")"
  [ -n "$B" ] && BUNDLE="$B"
fi
