# @quizzyjoy/shaderport

开源的 HarmonyOS **GPU 效果资产包**：48 个从 shaders.com（`shader-effects-inc/shaders`，MIT,
v4.0.4）移植的 GLSL ES 3.00 效果，附带可校验的 ArkTS 参数元数据。渲染由宿主应用负责，
本包提供 shader、默认值、参数约束与参考图。

- 效果数：**48**
- 渲染语言：**GLSL ES 3.00**（`#version 300 es`）
- 包类型：HAR（`@quizzyjoy/shaderport@0.1.0`）
- 许可：**Apache-2.0**（上游效果资产为 MIT，见 [THIRD_PARTY_NOTICES](https://github.com/quizzyjoy/shaderport/blob/main/THIRD_PARTY_NOTICES.md)）

## 下载安装

```bash
ohpm install @quizzyjoy/shaderport
```

## 所需权限

**无。** 本包只读取自身 `rawfile/effects/` 下的着色器、规格与参考图，
不申请系统权限、不访问网络、不写沙箱。

## 使用示例

```ts
import {
  initShaderPort,
  listEffects,
  getEffect,
  getPassSources,
  getDefaultParams,
  encodeParam,
} from '@quizzyjoy/shaderport';

// 1. 初始化（通常在页面 aboutToAppear 中调用一次）
initShaderPort(getContext(this).resourceManager);

// 2. 选择效果
const effects = listEffects();                 // EffectSummary[]
const spec = getEffect('plasma');              // 完整 EffectSpec

// 3. 取 pass 与默认值，交给宿主 native 渲染器
const passes = getPassSources('plasma');       // [{ fragment, block, instance }]
const defaults = getDefaultParams('plasma');   // [{ name: 'n_n.lightness', values: [...] }]

// 4. 用户改参数时编码为 UBO 路径 + 数值
const param = encodeParam('plasma', 'lightness', 0.5); // { name: 'n_n.lightness', values: [0.5] }
```

宿主 native 渲染器需要：

1. 创建 `XComponent` surface → `eglCreateWindowSurface` → `eglMakeCurrent`；
2. 为每个 pass 编译 `fragment` 源码，并链接宿主提供的全屏顶点着色器
   （`#version 300 es`，varying 统一命名 `_vs2fs_location0`）；
3. 按 `block` / `instance` 绑定 UBO，写入 `getDefaultParams()` 与 `encodeParam()` 的结果；
4. 多 pass 时在 pass 之间用 FBO 做 ping-pong，最后一个 pass 输出到窗口；
5. 每帧更新 `u_time` 等内置 uniform 与用户参数。

完整渲染契约（uniform 布局、Y 轴方向、sRGB、alpha、多 pass 规则）：

https://github.com/quizzyjoy/shaderport/blob/main/README.md#渲染契约

## 接口说明

| 接口 | 说明 |
|---|---|
| `initShaderPort(rm)` | 绑定 `resourceManager`；之后才可读取效果，重复调用幂等 |
| `listEffects()` | 返回 `EffectSummary[]`（来自 `index.json`） |
| `getEffect(id)` | 返回完整 `EffectSpec`（`passes` / `ubo` / `props` / `defaults` / `resolved`）；未知 id 抛错 |
| `getShaderSource(id, stage)` | 返回 final pass 的片元源码；`stage` 取 `'fragment'` 或 `''` |
| `getPassSources(id)` | 按渲染顺序返回 `PassSource[]`：`{ fragment, block, instance }` |
| `getDefaultParams(id)` | 返回 `ParamValue[]`：`{ name, values }`，已应用 `spec.resolved` |
| `getParamDescriptors(id)` | 返回 `ParamDescriptor[]`：`name` / `path` / `kind` / `label` / `min` / `max` / `step` / `value` / `options` / `optionValues` |
| `encodeParam(id, name, value)` | 将单个参数编码为 `{ name, values }`（颜色转线性、位置翻转 Y、枚举转码） |
| `validateParams(id, params)` | 返回 `{ ok, errors }`；检查未知参数与 `NaN` |

参数路径使用点号：`n_base.color`、`n_n.lightness`。颜色为线性 P3；
位置为 0..1 且 Y 轴向下（与 WGSL 一致）。

## 约束与限制

- **API 12+**（`compatibleSdkVersion 5.0.0(12)`），`arm64-v8a`。
- **GLES 3.0**；不支持 compute shader，也不提供 `#version 100` 回退。
- ArkTS 不能直接调用 GLES：必须由宿主用 XComponent + NAPI + native `.so` 渲染。
- 本包只提供资产与元数据，**不含渲染器**；不负责 EGL 配置、FBO 分配与帧循环。
- 不含需要 shape/child alpha 的 `Chrome`、`Neon`；不含状态模拟类效果。
- `MeshGradient` 为 `cost: high`，全分辨率可能掉帧，建议降分辨率或 `renderScale`。

## 目录结构

```
shaderport/
├── Index.ets                  # ArkTS 出口
└── src/main/
    ├── ets/
    │   ├── api.ets            # 公开 API
    │   └── types.ets          # 类型定义
    └── resources/rawfile/
        └── effects/
            ├── index.json     # 效果索引
            └── <id>/
                ├── spec.json      # 规格 + resolved 默认值 + 参数
                ├── passes/
                │   ├── final.glsl     # 单 pass；多 pass 另有 rtt_*.glsl
                │   └── …
                └── reference.png  # 512×512 参考图（P3 → sRGB 编码）
```

## 效果与性能

48 个效果按类别分为：纹理/生成器 19、形状 10、调色 10、扭曲 5、
风格化 2、模糊 1、交互 1。默认参数下的实测帧率（Mate 80 / Maleoon GPU）：

| 效果 | fps | 效果 | fps |
|---|---:|---|---:|
| SolidColor | 120.5 | Plasma | 60.2 |
| LinearGradient | 109.1 | PerlinNoise | 60.8 |
| RadialGradient | 120.5 | Blur | 57.6 |
| Aurora | 60.2 | Glow | 56.8 |
| FlowingGradient | 54.2 | MeshGradient | 11.8 |

`renderScale` 支持 `1.0 / 0.75 / 0.5`，对填充率受限效果（MeshGradient）收益明显。

完整设备矩阵：https://github.com/quizzyjoy/shaderport/blob/main/docs/device-matrix.md

## 文档

| 文档 | 链接 |
|---|---|
| 使用教程（从零接入） | https://github.com/quizzyjoy/shaderport/blob/main/docs/usage-guide.md |
| 规格格式 | https://github.com/quizzyjoy/shaderport/blob/main/docs/spec-format.md |
| 转换指南 | https://github.com/quizzyjoy/shaderport/blob/main/docs/conversion-guide.md |
| 设备矩阵 | https://github.com/quizzyjoy/shaderport/blob/main/docs/device-matrix.md |
| 签名策略 | https://github.com/quizzyjoy/shaderport/blob/main/docs/signing.md |
| 来源与命名 | https://github.com/quizzyjoy/shaderport/blob/main/docs/provenance-and-naming.md |
| 第三方声明 | https://github.com/quizzyjoy/shaderport/blob/main/THIRD_PARTY_NOTICES.md |

## 贡献

问题反馈与 PR：https://github.com/quizzyjoy/shaderport

- 新增/修改效果走 `tools/` 流水线，不要手改 `effects/` 生成产物；
- 提交前运行 `npm run export` → `npm run convert` → `npm run gate` → `npm run sync`；
- 详细规范见 https://github.com/quizzyjoy/shaderport/blob/main/CONTRIBUTING.md

## 开源协议

本包以 **Apache-2.0** 发布，见 `LICENSE`。
效果资产转译自 `shader-effects-inc/shaders`（MIT, v4.0.4），
许可与归属见
[THIRD_PARTY_NOTICES](https://github.com/quizzyjoy/shaderport/blob/main/THIRD_PARTY_NOTICES.md)。
