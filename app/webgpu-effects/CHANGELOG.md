# Changelog

All notable changes to `@virgo/webgpu-effects` are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-21

First published release. 199 effects running the upstream shaders 4.0.4 engine on a bundled WebGPU.

### Added

- **`ShaderView`** ArkUI component (XComponent surface, touch → cursor effects, visibility pause,
  incremental prop updates) and **`ShaderController`** (`update`, `pause`, `resume`, `stats`).
- **199 typed effect factories** generated from the upstream registry, with the upstream defaults:
  54 textures, 31 stylize, 23 shape effects, 22 distortions, 16 shapes, 16 interactive,
  14 adjustments, 13 transitions, 9 blurs, 1 utility (`Group`).
- **Native WebGPU**: `libwebgpu_effects.so` (NAPI ↔ `webgpu.h`) on wgpu-native with a Vulkan backend and
  `VK_OHOS_surface`; compute shaders, storage textures and multi-pass rendering supported.
- **Browser runtime shims** for the Ark JS engine: `window` / `document` / `requestAnimationFrame` (vsync-timed via
  displaySync) / 2D canvas / fonts / `Image` / `atob` / `btoa`.
- **Media inputs**: images from `rawfile://`, `https://`, `file://` and `data:` URLs; video via AVPlayer;
  camera via `WebcamTexture` (requests `ohos.permission.CAMERA` on first use).
- **Frame rate follows the display** (120 Hz on LTPO screens while touched); `setMaxFrameRate(fps)` to cap it.
- `initShaders`, `isSupported`, `setDebug`.

### Known limitations

- Real devices only — the emulator's Vulkan translation fails on most shaders.
- `HTMLInCanvas` (browser-only) is not provided.
