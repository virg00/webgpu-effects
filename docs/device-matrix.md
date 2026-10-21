# 设备矩阵与实测数据

> 由 `scripts/compare-bench.sh`（`TOUCH=1` 测触摸帧率）+ `scripts/build-compare-report.py` 生成的数据整理而来。
> 原始报告随演示应用打包：`app/entry/src/main/resources/rawfile/compare-report.json`。

## 已验证设备

| 设备 | 系统 | GPU 接口 | 结果 |
|---|---|---|---|
| LAP-AL10（三折叠） | HarmonyOS 7.0（API 26） | Vulkan | ✅ 199/199 效果可运行，含视频与摄像头输入 |
| HarmonyOS 6.1 模拟器（Apple Silicon） | API 24 | Vulkan（MoltenVK 转译） | ❌ 简单效果可运行，多数着色器转换失败，可能导致模拟器崩溃 |

欢迎通过 issue 补充其它设备的结果（型号、系统版本、`scripts/sweep.sh` 的 `summary.tsv`）。

## 单效果性能（LAP-AL10 三折叠 · HarmonyOS 7.0（API 26）· 同一个演示应用内测量，2026-10-21）

每个效果单独全屏渲染，预热 2.5 秒后取 5 秒平均；静止时屏幕 60Hz，触摸时 LTPO 屏升到 120Hz。
同时列出 [shaderport](https://github.com/quizzyjoy/shaderport) 在同一应用、同一设备上的数据作参照。
“与原版差异”为与上游原版（浏览器 WebGPU）截图的像素差，仅对静态效果有意义。

| 效果 | fps 静止 | fps 触摸 | CPU ms/帧 | 首帧 ms | 与原版差异 | shaderport fps 静止 / 触摸 | shaderport 差异 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Arc | 60 | 117 | 5.0 | 102 | 0.16% | 60 / 120 | 38.25% |
| Aurora | 60 | 117 | 5.1 | 172 | — | 60 / 120 | — |
| BlockNoise | 60 | 117 | 4.9 | 100 | — | 60 / 120 | — |
| Blur | 60 | 119 | 7.1 | 306 | — | 60 / 120 | — |
| BrightnessContrast | 60 | 120 | 5.2 | 187 | — | 60 / 120 | — |
| Checkerboard | 60 | 120 | 5.1 | 95 | 0.13% | 60 / 120 | 19.84% |
| Circle | 60 | 120 | 4.8 | 99 | 0.00% | 60 / 120 | 0.00% |
| Cross | 60 | 120 | 4.8 | 103 | 1.03% | 60 / 120 | 54.00% |
| CursorRipples | 60 | 118 | 6.3 | 306 | — | 60 / 120 | — |
| DotGrid | 60 | 120 | 5.0 | 102 | — | 60 / 120 | — |
| Duotone | 60 | 120 | 5.0 | 191 | — | 60 / 120 | — |
| Ellipse | 60 | 120 | 5.1 | 98 | 0.29% | 60 / 120 | 45.29% |
| Exposure | 60 | 120 | 5.1 | 177 | — | 60 / 120 | — |
| Flip | 60 | 120 | 5.1 | 186 | — | 60 / 120 | — |
| FlowingGradient | 60 | 120 | 5.1 | 199 | — | 60 / 120 | — |
| Glow | 60 | 116 | 7.8 | 263 | — | 60 / 120 | — |
| Grayscale | 60 | 120 | 5.1 | 187 | — | 60 / 120 | — |
| Grid | 60 | 120 | 5.0 | 105 | 1.54% | 60 / 120 | 2.42% |
| Heart | 60 | 120 | 4.8 | 97 | 0.32% | 60 / 120 | 51.88% |
| HexGrid | 60 | 120 | 5.0 | 110 | 1.49% | 60 / 120 | 1.90% |
| HueShift | 60 | 120 | 5.2 | 84 | — | 60 / 120 | — |
| Invert | 60 | 120 | 5.2 | 185 | — | 60 / 120 | — |
| LinearGradient | 60 | 120 | 4.9 | 99 | 0.22% | 60 / 119 | 0.21% |
| Marble | 60 | 120 | 4.9 | 123 | — | 60 / 120 | — |
| MeshGradient | 60 | 120 | 5.5 | 178 | — | 42 / 37 | — |
| Mirror | 60 | 120 | 5.0 | 204 | — | 60 / 120 | — |
| PerlinNoise | 60 | 120 | 5.0 | 110 | — | 60 / 120 | — |
| Plasma | 60 | 120 | 5.1 | 173 | — | 60 / 120 | — |
| PolarCoordinates | 60 | 120 | 5.0 | 195 | — | 60 / 120 | — |
| Polygon | 60 | 120 | 4.9 | 96 | 0.05% | 60 / 120 | 2.23% |
| Posterize | 60 | 120 | 5.1 | 180 | — | 60 / 120 | — |
| RadialGradient | 60 | 120 | 5.0 | 94 | 0.25% | 60 / 120 | 0.25% |
| RectangularCoordinates | 60 | 120 | 5.0 | 188 | — | 60 / 120 | — |
| Ring | 60 | 120 | 4.9 | 92 | 0.39% | 60 / 120 | 55.77% |
| Ripples | 60 | 120 | 5.0 | 97 | — | 60 / 120 | — |
| RoundedRect | 60 | 120 | 5.0 | 99 | 0.47% | 60 / 120 | 25.00% |
| Saturation | 60 | 120 | 5.1 | 89 | — | 60 / 120 | — |
| SimplexNoise | 60 | 120 | 5.1 | 116 | — | 60 / 120 | — |
| SineWave | 60 | 120 | 5.0 | 95 | — | 60 / 120 | — |
| SolidColor | 60 | 120 | 4.7 | 90 | 0.26% | 60 / 120 | 0.26% |
| Spiral | 60 | 120 | 5.1 | 100 | — | 60 / 120 | — |
| Star | 60 | 120 | 5.1 | 103 | 0.31% | 60 / 120 | 48.92% |
| Stripes | 60 | 120 | 5.0 | 97 | — | 60 / 120 | — |
| Teardrop | 60 | 120 | 4.8 | 98 | 0.27% | 60 / 120 | 48.25% |
| Tint | 60 | 120 | 5.2 | 188 | — | 60 / 120 | — |
| Tritone | 60 | 120 | 5.2 | 219 | — | 60 / 120 | — |
| Twirl | 60 | 120 | 5.1 | 184 | — | 60 / 120 | — |
| Vignette | 60 | 120 | 5.1 | 191 | — | 60 / 120 | — |

平均：静止 60.0 fps、触摸 119.6 fps、CPU 5.2 ms/帧、首帧 145 ms、PSS 198 MB。
shaderport：静止 59.5 fps、触摸 118.1 fps、CPU 1.6 ms/帧、首帧 151 ms、PSS 135 MB。

## 动画效果人工核对

| 效果 | webgpu-effects | shaderport |
|---|---|---|
| Aurora | 与原版一致 | 上下颠倒：光幕跑到了屏幕底部 |
| MeshGradient | 与原版一致 | 色块布局不同（meshAnchors 按 1:1 比例离线烘焙）；帧率 42 fps |
| SineWave | 与原版一致 | 整屏纯白，没有画出波形 |
| Stripes | 与原版一致（斜线方向相同） | 变成人字形折线 |
| Spiral | 与原版一致 | 旋臂方向与原版不同 |
| FlowingGradient | 与原版一致 | 基本一致（时刻不同） |
| Marble | 与原版一致 | 基本一致（时刻不同） |
| Ripples | 与原版一致 | 基本一致 |

## 复现

```bash
PRODUCT=devtest HDC_TARGET=<设备> scripts/compare-bench.sh build/compare
PRODUCT=devtest HDC_TARGET=<设备> TOUCH=1 scripts/compare-bench.sh build/compare-touch
python3 -I scripts/build-compare-report.py build/compare
```
