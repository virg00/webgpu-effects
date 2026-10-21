# 使用指南

本文覆盖 `@virgo/webgpu-effects` 的常见用法。API 一览见 [README](../README.md#api-参考)，效果与参数见 [effects.md](effects.md)
（参数的完整类型在包内 `components.ts` 的 `<Effect>Props` 中，IDE 可直接补全）。

## 1. 初始化

```ts
// entry/src/main/ets/entryability/EntryAbility.ets
import { initShaders } from '@virgo/webgpu-effects';

onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  initShaders(this.context);
}
```

页面出现到第一帧约 145 ms（LAP-AL10 实测，含着色器编译）。
可以先用 `await isSupported()` 判断设备是否可用，再决定是否显示特效。

## 2. 图层模型

`layers` 是从下往上的图层列表：

- **生成类**（渐变、噪声、形状、材质、图片……）画出新的内容，与下面的图层按 `blendMode` 混合；
- **滤镜类**（模糊、扭曲、调色、风格化、转场）**作用于之前绘制的全部图层**。

```ts
ShaderView({ layers: [
  MeshGradient(),
  Halftone({ id: 'dots' }),       // 作用于 MeshGradient
  Circle({ radius: 0.3, blendMode: 'screen', opacity: 0.6 }),
] })
```

想让滤镜只作用于部分图层，把那些图层作为第二个参数：

```ts
Blur({ intensity: 30 }, [ ImageTexture({ url: 'rawfile://bg.jpg' }) ])
```

`Group` 是弹性布局容器，可以把子图层排成行/列（`flow`、`absolute`、`boundingBox` 控制子图层位置）。

## 3. 更新参数

两种方式：

1. **声明式**：给 `layers` 一个新数组。只改参数时，变化的值会增量推送到正在运行的着色器；增删图层或换效果才会重建。
2. **控制器**：拖动滑块、手势等高频场景用 `controller.update(id, props)`，不经过 ArkUI 状态与比较。

```ts
private controller = new ShaderController();
ShaderView({ layers: this.layers, controller: this.controller })
Slider({ value: 0.5 }).onChange((v: number) => this.controller.update('fx', { intensity: v }))
```

`controller.pause()` / `resume()` 暂停与恢复渲染；`stats()` 返回最近一秒的 `{ fps, cpuMs }`。

## 4. 动态属性（PropDriver）

数值或坐标参数可以传一个驱动对象：

| `type` | 用途 | 主要字段 |
|---|---|---|
| `auto-animate` | 随时间循环 | `mode`（`ping-pong` / `loop`）、`outputMin`、`outputMax`、`speed`、`easing` |
| `mouse` | 随手指在一个方向上的位置变化 | `axis`（`x` / `y`）、`outputMin`、`outputMax`、`smoothing` |
| `mouse-position` | 坐标跟随手指 | `smoothing`、`momentum` |
| `map` | 读取另一个图层（需有 `id`）的亮度/透明度 | `source`、`channel`、`inputMin`、`inputMax`、`outputMin`、`outputMax` |

```ts
Circle({ id: 'blob', radius: { type: 'auto-animate', mode: 'ping-pong', outputMin: 0.2, outputMax: 0.5 } })
Blur({ intensity: { type: 'map', source: 'blob', channel: 'luminance', outputMin: 0, outputMax: 40 } })
```

跟手效果需要 `interactive`（默认开启）。

## 5. 遮罩

任何图层都可以用另一个图层做遮罩；遮罩源通常设为 `visible: false`：

```ts
ShaderView({ layers: [
  Star({ id: 'mask', visible: false, radius: 0.8 }),
  Aurora({ maskSource: 'mask', maskType: 'alpha' }),
] })
```

## 6. 图片、视频、摄像头

| 地址 | 说明 |
|---|---|
| `rawfile://path/to.jpg` | 宿主应用 `resources/rawfile` 下的文件 |
| `https://…` | 需宿主声明 `ohos.permission.INTERNET` |
| `file:///data/storage/el2/base/…` | 应用沙箱内文件 |
| `data:image/png;base64,…` | 内联图片 |

```ts
VideoTexture({ url: 'rawfile://clip.mp4', loop: true })
WebcamTexture()            // 需宿主声明 ohos.permission.CAMERA；首次使用时弹出授权
```

## 7. 预设

shaders.com 编辑器导出的 JSON 解析成对象后可以直接使用：`ShaderView({ preset: JSON.parse(text) as PresetConfig })`。

## 8. 性能建议

- 默认帧率跟随屏幕（LTPO 屏静止 60Hz、触摸 120Hz）。纯背景动画可 `setMaxFrameRate(60)`。
- 不在屏幕上的视图默认暂停（`pauseWhenHidden`）。
- 列表里大量缩略图请用静态图片，不要每个格子一个 `ShaderView`：每个视图都有自己的交换链与帧循环。
- `setDebug(true)` 后，GPU 校验错误与 WGSL 编译失败会输出到 hilog（tag `webgpu-fx`），`onShaderError` 也会收到。
