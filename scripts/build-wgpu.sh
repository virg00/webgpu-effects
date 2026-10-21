#!/bin/bash
# Cross-compile wgpu-native (Vulkan backend only) for OpenHarmony arm64 (devices) and x86_64 (emulator)
# and copy the static libraries + headers into the webgpu-effects library module.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SRC="$ROOT/native/wgpu-native"
OUT="$ROOT/app/webgpu-effects/src/main/cpp/third_party/wgpu"
N="$OHOS_NDK"
export LIBCLANG_PATH="$N/llvm/lib"
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$N/sysroot"
export CC_aarch64_unknown_linux_ohos="$N/llvm/bin/aarch64-unknown-linux-ohos-clang"
export CC_x86_64_unknown_linux_ohos="$N/llvm/bin/x86_64-unknown-linux-ohos-clang"
export AR_aarch64_unknown_linux_ohos="$N/llvm/bin/llvm-ar"
export AR_x86_64_unknown_linux_ohos="$N/llvm/bin/llvm-ar"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$N/llvm/bin/aarch64-unknown-linux-ohos-clang"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_OHOS_LINKER="$N/llvm/bin/x86_64-unknown-linux-ohos-clang"
WGPU_NATIVE_COMMIT=589e6ca   # v29.0.1.1-14
WGPU_HAL_VERSION=29.0.4
if [ ! -d "$SRC" ]; then
  git clone --recurse-submodules https://github.com/gfx-rs/wgpu-native "$SRC"
  git -C "$SRC" checkout "$WGPU_NATIVE_COMMIT"
  git -C "$SRC" submodule update --init
  git -C "$SRC" apply "$ROOT/native/wgpu-native-ohos.patch"
fi
if [ ! -d "$ROOT/native/wgpu-hal" ]; then
  # Unpack the published crate and apply the OpenHarmony patch.
  mkdir -p "$ROOT/native/wgpu-hal"
  curl -sL "https://static.crates.io/crates/wgpu-hal/wgpu-hal-$WGPU_HAL_VERSION.crate" | tar xz -C "$ROOT/native/wgpu-hal" --strip-components 1
  patch -d "$ROOT/native/wgpu-hal" -p2 < "$ROOT/native/wgpu-hal-ohos.patch"
fi
cd "$SRC"
# Optional crates.io mirror, e.g. CARGO_MIRROR=sparse+https://rsproxy.cn/index/
MIRROR=()
if [ -n "${CARGO_MIRROR:-}" ]; then
  MIRROR=(--config "source.crates-io.replace-with=\"mirror\"" --config "source.mirror.registry=\"$CARGO_MIRROR\"")
fi
# wgpu-hal with OpenHarmony Vulkan support (loader name + VK_OHOS_surface) (see native/wgpu-hal-ohos.patch)
PATCH=(--config "patch.crates-io.wgpu-hal.path=\"$ROOT/native/wgpu-hal\"")
export RUSTUP_TOOLCHAIN=stable  # upstream pins 1.93; any toolchain >= its rust-version (1.87) with the ohos targets works
for pair in "aarch64-unknown-linux-ohos:arm64-v8a" "x86_64-unknown-linux-ohos:x86_64"; do
  triple="${pair%%:*}"; abi="${pair##*:}"
  cargo build --release --target "$triple" --no-default-features --features wgsl,vulkan "${PATCH[@]}" ${MIRROR[@]+"${MIRROR[@]}"}
  mkdir -p "$OUT/lib/$abi"
  cp "target/$triple/release/libwgpu_native.a" "$OUT/lib/$abi/"
done
mkdir -p "$OUT/include"
cp ffi/webgpu-headers/webgpu.h ffi/wgpu.h "$OUT/include/"
ls -la "$OUT"/lib/*
