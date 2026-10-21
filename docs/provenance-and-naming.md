# 与上游的关系：隶属、命名与溯源

> 适用对象：`webgpu-effects` 项目及其产出的包、工具与文档。

## 结论速览

1. **隶属**：`webgpu-effects` 是**独立的第三方项目**，由 GitHub 用户 [virg00](https://github.com/virg00) 维护。
   它不是 `shader-effects-inc/shaders` 的官方移植，未获 Shader Effects Inc. 背书或赞助，两者没有任何组织关系。
2. **命名**：项目名、包名、原生库名**不包含上游品牌**（`shaders`、`shader-effects`、`shaders.com`）。
   与上游的关系只在文档中描述。
3. **溯源**：包内的上游引擎保留其版权与 MIT 许可（`THIRD_PARTY_NOTICES.md`），并记录上游版本（`upstream/VERSION`）。

## 隶属声明

README 醒目位置必须包含：

> `webgpu-effects` is an independent project. It is **not affiliated with, endorsed by, or sponsored by** Shader Effects Inc.
> or the `shader-effects-inc/shaders` project.

**禁止的表述**：

| 禁止 | 原因 |
|---|---|
| "official port of Shaders"、"Shaders 官方鸿蒙版" | 虚假官方身份 |
| "powered by Shaders"、"in partnership with Shader Effects Inc." | 暗示背书 |
| 使用上游 logo、图标、品牌色作为本项目标识 | 商标与视觉资产不可借用 |

**允许的表述**（描述性、事实性）：

- "runs the engine of `shader-effects-inc/shaders` (MIT)"、"效果来自 shaders.com 的开源引擎"
- "compatible with presets exported from the shaders.com editor"（已验证）

## 命名

| 对象 | 名称 |
|---|---|
| 仓库 | `virg00/webgpu-effects` |
| OHPM 包 | `@virg00/webgpu-effects` |
| HAR 模块 | `webgpu_effects` |
| 原生库 | `libwebgpu_effects.so` |
| 日志 tag | `webgpu-fx` |

代码内部沿用上游 API 的名字（如 `ShaderView`、`initShaders`、效果名 `LinearGradient`），因为它们描述的是功能、
与上游组件保持一一对应，不作为本项目的品牌使用。

## 溯源

| 内容 | 来源 | 许可 |
|---|---|---|
| 引擎与全部效果定义（`bundle.js`） | 上游 npm 包 `shaders`，版本见 `upstream/VERSION` | MIT，© Shader Effects Inc. |
| 工厂函数与参数类型（`components.ts`） | 由上游 `registry.js` 生成 | 同上 |
| WebGPU 实现、运行时垫片、组件、脚本 | 本项目原创 | MIT |
| wgpu-native / wgpu-hal 补丁 | 本项目对 gfx-rs 代码的修改 | MIT OR Apache-2.0（随原项目） |

对上游 bundle 的修改只通过 `scripts/patch-bundle.mjs` 进行，内容与原因见 [design.md](design.md#对上游-bundle-的补丁scriptspatch-bundlemjs)。
