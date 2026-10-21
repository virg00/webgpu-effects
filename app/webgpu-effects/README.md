# @virg00/webgpu-effects

鸿蒙上的 **WebGPU 实时特效组件**：199 个 GPU 效果（渐变、噪声、玻璃、金属、光影、流体、粒子、扭曲、转场、模糊、跟手效果），
一个 ArkUI 组件 `ShaderView` 即可使用。效果来自 shaders.com（`shader-effects-inc/shaders`，MIT，v4.0.4）——本包在原生层
实现了一套 WebGPU（wgpu-native on Vulkan），让上游引擎原样运行在方舟 JS 引擎上，因此效果、参数、混合与上游一致。

- 效果数：**199**（上游 200 个，仅缺浏览器专属的 `HTMLInCanvas`）
- 渲染：**WebGPU → Vulkan**（`VK_OHOS_surface` 输出到 XComponent）
- 包类型：HAR（`@virg00/webgpu-effects@1.0.0`），含 arm64-v8a 原生库
- 许可：**MIT**（上游引擎 MIT、wgpu MIT/Apache-2.0，见 [THIRD_PARTY_NOTICES](https://github.com/virg00/webgpu-effects/blob/main/THIRD_PARTY_NOTICES.md)）

`webgpu-effects` is an independent project. It is **not affiliated with, endorsed by, or sponsored by** Shader Effects Inc.
or the `shader-effects-inc/shaders` project.

## 下载安装

```bash
ohpm install @virg00/webgpu-effects
```

## 所需权限

**本包不声明任何权限。** 按用到的输入，由宿主应用在 `module.json5` 中声明：

| 用法 | 权限 |
|---|---|
| `ImageTexture` / `VideoTexture` 使用 `https://` 地址 | `ohos.permission.INTERNET` |
| `WebcamTexture`（摄像头） | `ohos.permission.CAMERA`（`user_grant`，首次使用时本包会弹出授权） |

`rawfile://`、`file://`（应用沙箱）与 `data:` 地址不需要权限。

## 使用示例

```ts
import { ShaderView, ShaderController, LinearGradient, CursorTrail, Glass, ImageTexture, Blur, Vignette,
  initShaders } from '@virg00/webgpu-effects';

// 1. EntryAbility.onCreate 中调用一次
initShaders(this.context);

// 2. 页面中：图层从下往上叠加
@Entry
@Component
struct Demo {
  private controller: ShaderController = new ShaderController();

  build() {
    Column() {
      ShaderView({ layers: [
        LinearGradient({ colorA: '#0f172a', colorB: '#7c3aed', angle: 45 }),
        CursorTrail(),                                     // 跟手效果
      ] })
        .width('100%').height(240)

      // 滤镜作用于之前绘制的图层
      ShaderView({ layers: [
        ImageTexture({ url: 'rawfile://hero.jpg', objectFit: 'cover' }),
        Blur({ id: 'blur', intensity: 40 }),
        Vignette({ intensity: 0.8 }),
      ], controller: this.controller })
        .width('100%').height(240)

      Slider({ value: 40, min: 0, max: 100 })
        .onChange((v: number) => this.controller.update('blur', { intensity: v }))   // 高频更新走控制器
    }
  }
}
```

动态属性（无需写动画代码）：

```ts
Circle({ radius: { type: 'auto-animate', mode: 'ping-pong', outputMin: 0.2, outputMax: 0.6, speed: 1 } })
Circle({ center: { type: 'mouse-position', smoothing: 0.12 } })   // 跟随手指
```

shaders.com 编辑器导出的预设：`ShaderView({ preset: json })`。

## 接口说明

| 接口 | 说明 |
|---|---|
| `ShaderView({ layers, preset, paused, interactive, pauseWhenHidden, colorSpace, toneMapping, controller, onReady, onShaderError })` | ArkUI 组件；`layers` 与 `preset` 二选一；`layers` 改变时只推送变化的参数，结构变化才重建 |
| `ShaderController` | `update(id, props)`、`pause()`、`resume()`、`stats()` → `{ fps, cpuMs }` |
| `initShaders(context)` | 绑定 `common.Context`（读取 rawfile、播放视频、打开相机需要），调用一次 |
| `setMaxFrameRate(fps)` | 帧率上限，默认 120（跟随屏幕刷新率）；设 60 可省电 |
| `isSupported()` | `Promise<boolean>`：当前设备能否创建 WebGPU 设备 |
| `setDebug(on)` | GPU 错误、WGSL 编译失败等诊断输出到 hilog（tag `webgpu-fx`） |
| `<Effect>(props?, children?)` | 199 个效果的工厂函数，返回 `ShaderNode`；参数类型 `<Effect>Props`，默认值与上游一致 |
| `SHADER_NAMES` | 全部效果名 |

**每个图层都支持**：`id`、`blendMode`（20 种）、`opacity`、`visible`、`maskSource` + `maskType`、`transform`、`boundingBox`、`flow`、`absolute`。

完整效果列表：[docs/effects.md](https://github.com/virg00/webgpu-effects/blob/main/docs/effects.md) ·
使用指南：[docs/usage-guide.md](https://github.com/virg00/webgpu-effects/blob/main/docs/usage-guide.md)

## 约束与限制

- **API 24+**（`compatibleSdkVersion 6.1.1(24)`），`arm64-v8a`，设备需支持 **Vulkan** 与 `VK_OHOS_surface`。
- **模拟器不可用**：模拟器的 Vulkan 转译层对多数着色器会转换失败；请用真机。
- 包体积约 **10.5 MB**（引擎 6.2 MB + 原生库 4.3 MB）；每帧 CPU 约 5 ms（LAP-AL10 实测）。
- `HTMLInCanvas` 依赖浏览器 DOM，不提供；文字类效果使用系统字体。
- 视频与摄像头帧经 CPU 上传（YUV → GPU 转换）。

## 效果与性能

| 类别 | 数量 | 类别 | 数量 |
|---|---:|---|---:|
| 纹理 Textures | 54 | 调色 Adjustments | 14 |
| 风格化 Stylize | 31 | 转场 Transitions | 13 |
| 材质 Shape Effects | 23 | 模糊 Blurs | 9 |
| 扭曲 Distortions | 22 | 工具 Utilities | 1 |
| 形状 Shapes | 16 | 交互 Interactive | 16 |

LAP-AL10（HarmonyOS 7.0）实测 48 个效果平均：屏幕 60Hz 时 60 fps，触摸时 LTPO 屏 120Hz 下 120 fps；
16 个静态效果与上游原版（浏览器 WebGPU）平均像素差异 0.45%。逐效果数据见
[device-matrix](https://github.com/virg00/webgpu-effects/blob/main/docs/device-matrix.md)。

## 开源协议

[MIT](https://github.com/virg00/webgpu-effects/blob/main/LICENSE)。源码：https://github.com/virg00/webgpu-effects
