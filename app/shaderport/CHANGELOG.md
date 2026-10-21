# Changelog

All notable changes to `@quizzyjoy/shaderport` are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-20

First published release. 48 effects, GLSL ES 3.00 assets, and the ArkTS consumer API.

### Added

- **48 effects**, grouped as:
  - 19 textures / generators (`Plasma`, `Marble`, `Aurora`, `MeshGradient`,
    `FlowingGradient`, `PerlinNoise`, `SimplexNoise`, `BlockNoise`, pattern
    generators, …)
  - 10 shapes (`Circle`, `RoundedRect`, `Polygon`, `Ring`, `Star`, `Ellipse`,
    `Heart`, `Teardrop`, `Arc`, `Cross`)
  - 10 adjustments (`BrightnessContrast`, `Duotone`, `HueShift`, `Exposure`,
    `Grayscale`, `Invert`, `Posterize`, `Saturation`, `Tint`, `Tritone`)
  - 5 distortions (`Twirl`, `Flip`, `Mirror`, `PolarCoordinates`,
    `RectangularCoordinates`)
  - 2 stylize filters (`Vignette`, `Glow`)
  - 1 blur (`Blur`, 2 RTT passes)
  - 1 interactive filter (`CursorRipples`, pointer-driven)
- **Effect packages** under `rawfile/effects/<id>/`: `spec.json`,
  `passes/*.glsl`, `reference.png`, and a generated `index.json`.
- **`spec.resolved`**: final uniform values (P3-linear colours, Y-inverted
  positions, enum codes, colour-stop arrays, per-frame `meshAnchors` /
  `convA..D`).
- **ArkTS API**: `initShaderPort`, `listEffects`, `getEffect`,
  `getShaderSource`, `getPassSources`, `getDefaultParams`,
  `getParamDescriptors`, `encodeParam`, `validateParams`.
- **Multi-pass support**: ordered passes with RTT ping-pong, sampler binding and
  premultiplied-alpha intermediate targets.
- **Validation metadata** (`spec.validation.pixelDiff`) with strict defaults
  and a documented per-effect override for driver-sensitive noise.
- **Documentation**: spec format, conversion guide, device matrix, signing
  policy, provenance policy and the 1.0 roadmap.

### Requirements

- HarmonyOS **API 12+** (`compatibleSdkVersion 5.0.0(12)`).
- **OpenGL ES 3.0** (`#version 300 es`); compute shaders are not supported.
- `arm64-v8a`.
- The host application must provide the native renderer
  (XComponent + EGL/GLES); ArkTS cannot execute GLES directly.
- **No permissions** are requested by this package; only bundled rawfile assets
  are read.

### Known limitations

- Effects that require a shape/child alpha mask (`Chrome`, `Neon`) are not
  included.
- Stateful simulations (smoke, reaction-diffusion, boids) are not included;
  they need cross-frame GPU state.
- `MeshGradient` is GPU-heavy at full resolution (`cost: high`); render it at a
  reduced scale or half-resolution RTT.
- `meshAnchors` are baked at a 1:1 aspect during export, so non-square
  viewports are consistent across devices but slightly differ from the
  upstream per-frame recomputation.

### Links

- Repository: https://github.com/quizzyjoy/shaderport
- Homepage: https://github.com/quizzyjoy/shaderport
- Issues: https://github.com/quizzyjoy/shaderport/issues
- License: Apache-2.0 (third-party content under MIT, see `THIRD_PARTY_NOTICES.md`)
