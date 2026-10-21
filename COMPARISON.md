# Claude 版 vs shaderport：shaders 鸿蒙移植对比

两份都是上游 [shaders](https://github.com/shader-effects-inc/shaders) 4.0.4 的 HarmonyOS 移植：

- **Claude 版**（本仓库）：在运行时直接跑上游引擎，自带 WebGPU（NAPI → wgpu-native → Vulkan），对外是一个 ArkUI 组件 `ShaderView`。
- **shaderport**（[quizzyjoy/shaderport](https://github.com/quizzyjoy/shaderport) 0.1.0，Apache-2.0）：离线用 naga 把效果的 WGSL 转成 GLSL ES 3.00，由宿主自己写的 GLES 渲染器绘制。

两者都已集成进演示应用：首页「对比 shaderport」是对比菜单（两边都有的效果可以分屏对比），「对比分析」是本文的数据页。

## 为什么一个是 WebGPU、一个是 GLES 3

上游库只支持 WebGPU（运行时生成的 WGSL 着色器、计算着色器）。鸿蒙原生没有 WebGPU（ArkWeb 里的 `navigator.gpu` 也拿不到适配器），于是有两种做法：

- shaderport：把着色器**离线翻译**成 GLES 3.0 的 GLSL，上游引擎在 CPU 侧做的事（组合、参数打包、动画时间、驱动）由宿主重写；GLES 3.0 没有计算着色器，相关效果放弃。
- Claude 版：在原生层**实现一套 WebGPU 接口**，底下用 Vulkan 执行（Chrome 在安卓上也是这样实现 WebGPU 的），上游引擎原样运行。

所以 Claude 版更符合原版（见下面的还原度数据）；GLES 3 的好处是兼容更老的系统和模拟器、体积更小。

## 测量方法

- 设备：LAP-AL10 三折叠，HarmonyOS 7.0（API 26）。两边跑在同一个演示应用里，shaderport 的 HAR 和它自带的参考渲染器原样接入（只改了 NAPI 模块名）。
- 性能：48 个共同效果，每个效果分别让一侧**单独全屏**渲染，预热 2.5 秒后取 5 秒平均（`scripts/compare-bench.sh`）。这台手机静止时屏幕是 60Hz、触摸时升到 120Hz，两种状态各测一遍（`TOUCH=1` 在采样期间持续滑动）。上游引擎原本把帧率封顶在 60，鸿蒙版已放开为跟随屏幕（`setMaxFrameRate` 可调）。两边参数用相同默认值，滤镜类都叠在同一个 Plasma 底图上（与 shaderport 的固定组合保持一致）。
- 还原度：在 Mac 的 Chrome 里用 WebGPU 直接运行上游 npm 包，按手机视图同样的宽高比渲染、黑底合成后截图作为**原版基准**；与两边的真机截图比较视图中部的同一区域（`scripts/build-compare-report.py`）。动画类效果两边时钟不同步，改为逐个人工核对。

## 结果

| 指标 | Claude 版 | shaderport |
|---|---|---|
| 效果数量 | **199**（上游 200 个里只缺浏览器专属的 HTMLInCanvas） | 48 |
| 与原版差异（16 个静态效果，平均） | **0.45%**（16/16 在 3% 以内） | 24.7%（7/16 在 3% 以内） |
| 动画效果人工核对（8 个） | **8/8 与原版一致** | Aurora 上下颠倒、SineWave 整屏纯白、Stripes 变人字形、Spiral 方向不同、MeshGradient 布局不同 |
| 帧率：触摸时（LTPO 屏 120Hz，48 个效果平均） | 120 fps | 118 fps（MeshGradient 只有 37 fps） |
| 帧率：静止时（屏幕 60Hz） | 60 fps | 59.5 fps（MeshGradient 只有 42 fps） |
| 每帧 CPU 耗时 | 5.2 ms | **1.6 ms** |
| 进程内存 PSS | 198 MB | **135 MB**（且含已加载但空闲的 Claude 引擎） |
| 页面到首帧 | 145 ms | 151 ms |
| 库体积（arm64，运行时必需） | 约 10.5 MB | **约 1 MB**（另带 5.3 MB 可删的参考图） |
| 系统要求 | Vulkan 1.1，当前构建 API 24 | **GLES 3.0，API 12+** |
| 模拟器 | 复杂效果会让模拟器的 Vulkan 转译层崩溃，需真机 | **可用** |

还原度差异的主要原因：

- shaderport 的形状类（Heart、Star、Cross、Ring、Ellipse、Arc、Teardrop、RoundedRect）在默认参数下整屏填满（其 README 称"radius=1 填满画布属预期"），而上游原版画出的是实际形状。
- shaderport 参考渲染器把每个节点的 `_animTime` 直接写成全局时间；上游按 `deltaTime × speed` 累加，所以 shaderport 里所有 `speed` 参数不生效，默认 speed≠1 的效果动画节奏不同。
- Checkerboard 格子不是正方形；MeshGradient 的色块锚点按 1:1 比例离线烘焙。

## 功能

| | Claude 版 | shaderport |
|---|---|---|
| 计算着色器 / 跨帧模拟（Boids、烟雾、反应扩散、流体粒子…） | ✅ | ❌（GLES 3.0 无 compute） |
| 任意图层组合、20 种混合模式、遮罩 | ✅ | ❌（固定的预组合） |
| 属性驱动（自动动画、跟手、读取其它图层） | ✅ | ❌ |
| 图片 / 视频 / 摄像头 / 文字输入 | ✅ | ❌（滤镜输入固定为 Plasma） |
| 接入方式 | 一个 ArkUI 组件 + 200 个带类型的工厂函数 | 只提供 GLSL 和参数元数据，渲染器要自己写（参考实现约 1000 行 C++） |
| 跟进上游新版本 | `scripts/sync-upstream.sh` 一条命令 | 逐效果重新导出、转换、生成规格和参考图 |

## 结论

- **要效果全、能组合、能接图片/视频/摄像头、要和上游原版保持一致，选 Claude 版。** 它跑的就是上游引擎本身，测得的还原度和功能覆盖都明显领先，帧率持平（60Hz 和 120Hz 下都是）。
- **只需要几十个基础背景、形状、调色效果，在意包体积，或者要支持 HarmonyOS 5 和模拟器，shaderport 更轻。** 它的 CPU 开销、内存和包体积都明显更小。

Claude 版目前的主要短板：库体积（约 10 倍）、每帧 CPU 开销（约 3 倍，但只占帧预算的三分之一）、模拟器不可用、最低 API 版本较高。
