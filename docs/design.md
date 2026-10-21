# 设计说明

## 目标

在鸿蒙上提供与上游 [shaders](https://github.com/shader-effects-inc/shaders) **行为一致**的效果库，并能低成本跟进上游版本。

上游的效果不是一组固定的着色器：引擎在运行时根据图层树、参数类型和混合方式，用 TypeGPU 拼出 WGSL，
部分效果还依赖计算着色器、存储纹理和跨帧状态。因此"把每个效果的着色器翻译一遍"只能覆盖其中一部分，
而且引擎在 CPU 侧做的事（组合、参数打包、动画时间、属性驱动、布局）都要重写。

本项目选择**不改动上游引擎**，而是把它需要的运行环境补齐：

```
ShaderView.ets ─ host.ts ─┬─ bundle.js   上游引擎（构建时打两处补丁）
                          ├─ runtime.js  浏览器环境垫片
                          └─ webgpu.js   WebGPU 对象模型
                                 │ NAPI
                          libwebgpu_effects.so (gpu.cpp)
                                 │ webgpu.h
                          wgpu-native (static) → Vulkan → VK_OHOS_surface
```

## 分层

### ShaderView / host.ts

- ArkUI 组件，内部是一个 `XComponent`（surface 类型）。surface 创建/销毁、尺寸变化、可见性与触摸事件转发给 `ShaderHost`。
- `ShaderHost` 把 `layers`（工厂函数生成的 `ShaderNode` 树）转成上游引擎的 preset 结构，比较前后两次的结构与参数：
  结构不变只推送变化的参数，结构变化才重建。
- 解析媒体地址（`rawfile://`、`https://`、`file://`、`data:`），图片解码为 `PixelMap` 后交给运行时。

### runtime.js

上游引擎是为浏览器写的，运行时提供它用到的最小环境：

- `window`、`document`、`HTMLCanvasElement`（屏幕画布 = 一个 XComponent surface）、`ResizeObserver`、`IntersectionObserver`；
- `requestAnimationFrame`：由 `displaySync` 驱动，回调时间戳取**垂直同步时间**（而不是回调实际执行时间），否则引擎的帧间隔判断会因抖动丢帧；
- 2D 画布（文字、渐变等辅助纹理）：映射到 ArkUI `OffscreenCanvas`；
- `Image`、`HTMLVideoElement`（AVPlayer）、`navigator.mediaDevices.getUserMedia`（Camera Kit）、`atob` / `btoa`、字体加载。

### webgpu.js + gpu.cpp

- `webgpu.js` 实现 `navigator.gpu` 与全部 `GPU*` 类，参数校验与默认值按 WebGPU 规范处理，然后调用 NAPI。
- `gpu.cpp` 是 `webgpu.h` 的薄封装：对象以 `napi_external` 持有，随 JS 对象回收释放；缓冲区映射直接共享内存。
- 交换链纹理（`getCurrentTexture()`）以**不持有所有权**的 external 交给 JS：它的生命周期属于 surface，
  否则 GC 晚于 surface 销毁释放时 wgpu 会中止进程。
- 外部纹理（视频/摄像头）：wgpu 不支持 `texture_external`，`webgpu.js` 在 WGSL 层把它改写为普通 2D 纹理，
  视频帧（NV12/YUV）上传后用一个计算/渲染 pass 转为 RGBA。

### wgpu-native

- 交叉编译为 `aarch64-unknown-linux-ohos` 静态库，与 `gpu.cpp` 链接成一个 `.so`（`--exclude-libs,ALL`、`--gc-sections`，约 4.3 MB）。
- `wgpu-hal` 补丁：Vulkan 后端增加 `VK_OHOS_surface`（从 `OHNativeWindow` 创建 surface），加载 `libvulkan.so`；
  另有若干针对模拟器驱动的兼容处理（真机不受影响）。
- naga 在运行时把 WGSL 编译为 SPIR-V。

## 对上游 bundle 的补丁（`scripts/patch-bundle.mjs`）

1. **方舟运行时缺陷**：`this.#x = v` 作为表达式使用时，结果是 `true` 而不是 `v`。补丁用 AST 找到这类用法（约 10 处），
   改写为逗号表达式 `(this.#x = v, this.#x)`，语义不变。
2. **帧率上限**：引擎把最小帧间隔写死为约 16.7 ms（60 fps）。补丁改为读取 `globalThis.__SHADERS_MIN_FRAME_INTERVAL`，
   由 `setMaxFrameRate` 设置，默认跟随屏幕（120 Hz）。

补丁在 `scripts/sync-upstream.sh` 中自动执行；`upstream/` 保留未修改的原始文件以便核对。

## 为什么不用 GLES

另一条路线是离线把 WGSL 转成 GLSL ES（[shaderport](https://github.com/quizzyjoy/shaderport) 的做法）。它体积小、
兼容老系统和模拟器，但 GLES 3.0 没有计算着色器，且引擎的 CPU 侧逻辑要逐个重写。实测对比见 [COMPARISON.md](../COMPARISON.md)。

## 代码生成

- `scripts/gen-components.mjs`：从上游 `registry.js` 生成 199 个工厂函数与 `<Effect>Props` 类型（含默认值、范围、枚举），
  以及演示应用的 `catalog.json`。
- `scripts/gen-effects-doc.py`：生成 [effects.md](effects.md)。
