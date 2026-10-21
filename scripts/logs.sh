#!/bin/bash
# Dump this app's recent logs (shaders/webgpu domain + JS console + crashes) from $HDC_TARGET.
source "$(dirname "$0")/env.sh"
hdc -t "$TARGET" shell "hilog -x" | grep -E "A05348|JSAPP|jsapp|Ace|webgpu-fx|wgpu|Fatal|CppCrash|ArkCompiler|${BUNDLE}" | grep -v "ImageSource\|Ace Inspector" | tail -${1:-80}
