# 效果目录

共 199 个效果（上游 200 个，`HTMLInCanvas` 依赖浏览器 DOM，鸿蒙上不提供）。
「需要输入」表示该效果作用于之前绘制的图层（滤镜类）。每个效果都有同名的带类型工厂函数，参数见 `components.ts` 里的 `<Name>Props`。

| 分类 | 数量 |
|---|---|
| 材质（Shape Effects） | 23 |
| 纹理（Textures） | 54 |
| 交互（Interactive） | 16 |
| 风格化（Stylize） | 31 |
| 扭曲（Distortions） | 22 |
| 模糊（Blurs） | 9 |
| 调色（Adjustments） | 14 |
| 转场（Transitions） | 13 |
| 形状（Shapes） | 16 |
| 工具（Utilities） | 1 |

## 推荐

演示应用首页的排序（视觉效果最好的在前）：

`LiquidMetal`、`Glass`、`Crystal`、`Chrome`、`Holographic`、`Nebula`、`Boids`、`Aurora`、`MeshGradient`、`Godrays`、`Neon`、`Hologram`、`Plastic`、`Obsidian`、`ThinFilm`、`Water`、`Goo`、`Frost`、`BrushedMetal`、`CarbonFiber`、`Irradiance`、`LightEdge`、`Smoke`、`ParticleFlow`、`InkFlow`、`ReactionDiffusion`、`MagneticFilings`、`FloatingParticles`、`Particles`、`ParticleField` …

## 材质（Shape Effects，23）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `BrushedMetal` | 拉丝金属 | 逼真的拉丝铝/钢/金/铜表面与各向异性反光 |  |
| `CarbonFiber` | 碳纤维 | 逼真的编织碳纤维与清漆反光 |  |
| `Chrome` | 镜面铬 | 影棚布光下的镜面铬金属，带倒角与冷暖条灯 |  |
| `Crystal` | 钻石水晶 | 多切面折射的钻石透镜 | 是 |
| `Emboss` | 浮雕 | 按自定义形状压出浮雕/凹印 | 是 |
| `Frost` | 冰霜 | 逼真的冰块次表面散射与边缘霜花 |  |
| `Glass` | 玻璃透镜 | 光学级真实玻璃折射 | 是 |
| `Goo` | 粘液 | 逼真的湿润液态元球，融合鼓胀 |  |
| `Heatmap` | 热成像 | 热像仪般在形状中流动的热量 |  |
| `Hologram` | 全息投影 | 科幻体积全息投影，带扫描线与闪烁 |  |
| `Holographic` | 镭射贴纸 | 带彩虹光泽与闪粉的全息镭射膜 |  |
| `Irradiance` | 边缘辐照 | 彩色点光照亮形状边缘并向外辐射，带真实投影 |  |
| `LightEdge` | 流光描边 | 绕形状边缘奔跑的发光光带 |  |
| `LiquidMetal` | 液态金属 | 包裹形状流动的熔融镜面金属 |  |
| `Nebula` | 瓶中星云 | 封在抛光玻璃中的体积星云与星场 |  |
| `Neon` | 霓虹灯管 | 逼真的霓虹灯管/3D 管道 |  |
| `Obsidian` | 黑曜石 | 正面近黑、侧壁燃起流动虹彩的暗色玻璃 |  |
| `Particles` | 粒子成形 | 粒子群填满形状，被手指惊散后又飞回 |  |
| `Plastic` | 光面塑料 | 带影棚反射的光滑注塑塑料 |  |
| `SmokeFill` | 形状烟雾 | 在形状内翻滚的流体烟雾 |  |
| `ThinFilm` | 薄膜干涉 | 彩虹般的薄膜干涉边缘 |  |
| `Voxels` | 体素 | 用体素重建形状，带环境光遮蔽与投影 |  |
| `Water` | 水体 | 折射吸光的水体，风吹波面与浪花 |  |

## 纹理（Textures，54）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `Aurora` | 极光 | 层层光幕、垂直光束与流动光芒的北极光 |  |
| `Beam` | 光束 | 从一点射向另一点的光束 |  |
| `Blob` | 有机团块 | 带 3D 光照与渐变的有机动态团块 |  |
| `BlockNoise` | 方块噪声 | 柔边方块值噪声，随时间变形 |  |
| `BlueNoise` | 蓝噪声 | 均匀细密的高频颗粒，适合抖动 |  |
| `BrickPattern` | 砖墙 | 交错排列的砖块与灰缝 |  |
| `Checkerboard` | 棋盘格 | 两种颜色交替的棋盘格 |  |
| `Chevron` | 人字纹 | 动态锯齿/人字条纹 |  |
| `ColorWheel` | 色轮渐变 | 循环彩虹色的方向渐变 |  |
| `ConicGradient` | 锥形渐变 | 绕中心一圈扫过的色彩 |  |
| `CurlNoise` | 旋度噪声 | 缓缓漂移的旋涡流场 |  |
| `DiamondGradient` | 菱形渐变 | 从中心发散的菱形渐变 |  |
| `DotGrid` | 点阵 | 可闪烁的圆点网格 |  |
| `ErosionNoise` | 侵蚀地貌 | 水流侵蚀出的分叉山脊噪声 |  |
| `FallingLines` | 下落线条 | 带渐隐拖尾的定向下落线 |  |
| `FloatingParticles` | 漂浮微粒 | 成千上万闪烁漂浮的真实粒子，手指可吹散 |  |
| `FlowingGradient` | 流动丝绸渐变 | 有机流动的丝绸色带 |  |
| `FractalNoise` | 分形噪声 | 多倍频分形布朗运动噪声 |  |
| `GaborNoise` | Gabor 噪声 | 指纹般的定向正弦颗粒 |  |
| `Godrays` | 丁达尔光 | 从一点发出的体积光束 |  |
| `Grid` | 网格线 | 可调粗细与旋转的网格 |  |
| `HexGrid` | 蜂窝网格 | 六边形蜂窝网格 |  |
| `ImageTexture` | 图片 | 显示图片，可选填充方式 |  |
| `IsometricCubes` | 等距立方体 | 立方体错觉的菱形镶嵌 |  |
| `LinearGradient` | 线性渐变 | 平滑的线性渐变 |  |
| `Marble` | 大理石 | 经典大理石纹理 |  |
| `MeshGradient` | 网格渐变 | 柔和漂移的色块流动渐变 |  |
| `MultiPointGradient` | 多点渐变 | 五个可拖动色点混合的渐变 |  |
| `PerlinNoise` | 柏林噪声 | 随时间变形的平滑噪声 |  |
| `Plasma` | 等离子 | 发光的等离子动画 |  |
| `Prism` | 棱镜分光 | 光束散开成缓缓旋转的彩虹 |  |
| `RadialGradient` | 径向渐变 | 从中心向外的渐变 |  |
| `Ripples` | 涟漪 | 从一点扩散的同心波纹 |  |
| `Satin` | 绸缎 | 随风轻摆、带真实光泽的绸缎褶皱 |  |
| `Scratches` | 划痕 | 旧胶片般的细划痕 |  |
| `SimplexNoise` | 单纯形噪声 | 有机流动的噪声 |  |
| `SineWave` | 正弦波 | 可调粗细柔度的波浪线 |  |
| `SolidColor` | 纯色 | 纯色填充 |  |
| `Spiral` | 螺旋 | 旋转的螺旋图案 |  |
| `Strands` | 光丝 | 多色渐变的流动光带 |  |
| `Stripes` | 条纹 | 动态交替条纹 |  |
| `StudioBackground` | 影棚背景 | 多灯位影棚背景与环境光动画 |  |
| `SunBurst` | 放射光芒 | 从中心放射的光芒条纹 |  |
| `Swirl` | 漩涡 | 多层噪声的流动漩涡 |  |
| `Text` | 文字 | 多行文字，按字形纹理清晰渲染 |  |
| `TriangularGrid` | 三角网格 | 等边三角形镶嵌网格 |  |
| `Truchet` | 特鲁谢迷宫 | 四分之一圆弧拼成的迷宫曲线 |  |
| `VideoTexture` | 视频 | 播放视频作为纹理 |  |
| `Voronoi` | 泰森多边形 | 按最近点距离着色的细胞图案 |  |
| `Waveform` | 音频波形 | 均衡器柱/波形/示波器等可视化 |  |
| `WaveletNoise` | 小波噪声 | 旋转带状的小波噪声 |  |
| `Weave` | 编织纹 | 两色经纬线交织的布纹 |  |
| `WebcamTexture` | 摄像头 | 实时摄像头画面（需授权相机） |  |
| `WorleyNoise` | Worley 噪声 | 基于距离的细胞噪声 |  |

## 交互（Interactive，16）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `Boids` | 鸟群模拟 | 数百个群体智能体结成流动的队列，手指可吸引或惊散它们 |  |
| `ChromaFlow` | 彩色流体 | 跟随手指流动的液态色彩（请在屏幕上滑动） |  |
| `CursorRipples` | 触摸涟漪 | 手指划过激起流体般的涟漪 | 是 |
| `CursorTrail` | 光标拖尾 | 跟随手指的动态拖尾（请在屏幕上滑动） |  |
| `Fog` | 雾气 | 充满屏幕、可被手指搅动的雾 |  |
| `GridDistortion` | 网格扭曲 | 随手指扭曲的网格（请在屏幕上滑动） | 是 |
| `InkFlow` | 流体墨迹 | 拖动在真实流体中画出旋转的墨带（请在屏幕上滑动） |  |
| `Liquify` | 液化 | 可用手指推动的液化变形（请在屏幕上滑动） | 是 |
| `MagneticFilings` | 磁力铁屑 | 成千上万铁屑沿手指周围的磁力线排列 |  |
| `ParticleFlow` | 流体粒子 | 真实不可压缩流体携带的尘埃粒子，手指搅动出涡流 |  |
| `PixelSort` | 像素排序 | 手指周围的像素按亮度排序（请在屏幕上滑动） | 是 |
| `PixelThrow` | 像素抛洒 | 沿手指轨迹把像素像流体一样甩出 | 是 |
| `ReactionDiffusion` | 反应扩散 | 活的 Gray-Scott 图案，手指划过处会生长 |  |
| `Shatter` | 碎玻璃 | 板块错动的碎玻璃效果 | 是 |
| `Smoke` | 烟雾 | 带涡度的真实流体烟雾模拟 |  |
| `SmokeFlow` | 手指烟雾 | 跟随手指、盘旋消散的烟（请在屏幕上滑动） |  |

## 风格化（Stylize，31）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `Ascii` | ASCII 字符画 | 把画面转成 ASCII 字符艺术 | 是 |
| `CRTScreen` | CRT 显示器 | 复古显像管屏幕与扫描线 | 是 |
| `Chalkboard` | 黑板粉笔画 | 把画面变成黑板上的粉笔素描 | 是 |
| `ChromaticAberration` | 色差 | RGB 通道分离的棱镜色散 | 是 |
| `CompressionArtifacts` | 压缩失真 | 模拟 JPEG 有损压缩的块效应与振铃 | 是 |
| `ContourLines` | 等高线 | 按亮度绘制地形等高线 | 是 |
| `DataMosh` | 数据溃码 | 视频丢关键帧般的宏块拖影 | 是 |
| `Dither` | 抖动 | 多种图案的抖动效果 | 是 |
| `DropShadow` | 投影 | 按内容轮廓添加柔和阴影 | 是 |
| `Engraving` | 铜版雕刻 | 钞票肖像般的线条雕刻 | 是 |
| `FilmGrain` | 胶片颗粒 | 偏向暗部的胶片颗粒 | 是 |
| `Glitch` | 故障艺术 | 像素熔化与色彩错乱的数字故障 | 是 |
| `Glow` | 辉光 | 柔和发光 | 是 |
| `GradientMap` | 渐变映射 | 按亮度映射到动态渐变（类 PS 渐变映射） | 是 |
| `Halftone` | 半调网点 | 印刷风格的网点效果 | 是 |
| `KeyFrames` | 运动追踪 | 像合成软件追踪中一样标记运动轨迹 | 是 |
| `LensDistortion` | 镜头畸变 | 桶形/枕形畸变与色彩分层 | 是 |
| `LensFlare` | 镜头光晕 | 逼真的相机镜头眩光 |  |
| `LightLeak` | 漏光 | 胶片漏光：暖色过曝光从一角渗入 | 是 |
| `ObjectTracker` | 目标检测 | 计算机视觉风格的检测框与标签 | 是 |
| `Paper` | 纸张质感 | 真实纸纹与粗糙度 | 是 |
| `ParticleField` | 粒子浮雕 | 把画面炸成会呼吸的 3D 粒子场，手指可抛掷粒子 | 是 |
| `Pixelate` | 像素化 | 可调格子大小的马赛克 | 是 |
| `ReflectivePlane` | 镜面地板 | 倒映上方内容的反光地面 | 是 |
| `Sparkle` | 星光闪烁 | 亮部闪烁的星芒 | 是 |
| `Stone` | 石材浮雕 | 大理石纹理浮雕与表面扭曲 | 是 |
| `TimeTrail` | 时间拖影 | 运动物体留下长曝光般的拖影 | 是 |
| `VHS` | VHS 录像带 | 模拟录像带的磁带损伤、色渗与扫描线噪声 | 是 |
| `Vignette` | 暗角 | 压暗或着色画面四周 | 是 |
| `Watercolor` | 水彩 | 水彩画风：颜料边缘、纸纹与晕染 | 是 |
| `Wool` | 羊毛织物 | 交织纤维的织物质感 | 是 |

## 扭曲（Distortions，22）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `BarShift` | 错位条带 | 把画面切成平行条带各自偏移，碎裂/故障感 | 是 |
| `Bend` | 曲面弯折 | 像曲面屏一样把画面两端弯向你 | 是 |
| `Bulge` | 凸起/收缩 | 围绕中心放大或收缩画面 | 是 |
| `ConcentricSpin` | 同心旋转 | 一圈圈同心环各自旋转画面 | 是 |
| `CornerPin` | 四角透视 | 任意拖动四角做透视变形 | 是 |
| `DisplacementMap` | 置换贴图 | 用另一图层驱动画面扭曲 | 是 |
| `Flip` | 翻转 | 水平/垂直镜像 | 是 |
| `FlowField` | 流场扭曲 | 持续平滑流动的流体扭曲 | 是 |
| `FlutedGlass` | 长虹玻璃 | 透过重复柱面条纹折射画面 | 是 |
| `Form3D` | 3D 包裹 | 把内容包到光线步进的 3D 形体上 | 是 |
| `GlassTiles` | 玻璃砖 | 网格状的折射扭曲 | 是 |
| `Kaleidoscope` | 万花筒 | 径向镜像分段的万花筒 | 是 |
| `Mirror` | 镜像 | 沿任意直线镜像 | 是 |
| `Perspective` | 3D 透视 | 平面在 3D 空间中平移倾斜 | 是 |
| `PolarCoordinates` | 极坐标 | 直角坐标转极坐标 | 是 |
| `RectangularCoordinates` | 直角坐标 | 极坐标转回直角坐标 | 是 |
| `Repeater` | 阵列复制 | 网格/环形/线性重复内容 | 是 |
| `Spherize` | 球面化 | 把内容映射到 3D 球面 | 是 |
| `Stretch` | 拉伸 | 从中心向某方向拉伸 | 是 |
| `Surface3D` | 3D 波浪曲面 | 把内容铺在带光照的 3D 波面上 | 是 |
| `Twirl` | 扭转 | 围绕中心扭曲旋转 | 是 |
| `WaveDistortion` | 波浪扭曲 | 多种波形的扭曲 | 是 |

## 模糊（Blurs，9）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `AngularBlur` | 旋转模糊 | 围绕中心点旋转的径向运动模糊 | 是 |
| `Blur` | 高斯模糊 | 经典高斯模糊 | 是 |
| `BokehBlur` | 焦外散景 | 高光化作光圈形状光斑的镜头虚化 | 是 |
| `ChannelBlur` | 分通道模糊 | 红绿蓝通道分别模糊 | 是 |
| `DiffuseBlur` | 扩散模糊 | 颗粒状随机像素位移 | 是 |
| `LinearBlur` | 方向模糊 | 指定角度的运动模糊 | 是 |
| `ProgressiveBlur` | 渐进模糊 | 向一个方向逐渐加强的模糊 | 是 |
| `TiltShift` | 移轴 | 移轴摄影的选择性对焦 | 是 |
| `ZoomBlur` | 缩放模糊 | 从中心向外的放射变焦模糊 | 是 |

## 调色（Adjustments，14）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `BrightnessContrast` | 亮度对比度 | 调整亮度与对比度 | 是 |
| `Duotone` | 双色调 | 按亮度映射为两种颜色 | 是 |
| `Exposure` | 曝光 | 乘性曝光增益，可推出 HDR 高光 | 是 |
| `FilmStock` | 胶片色彩 | 十种经典胶片 LUT，含光晕与片门抖动 | 是 |
| `Grayscale` | 黑白 | 转为黑白 | 是 |
| `HueShift` | 色相偏移 | 绕色轮旋转色相 | 是 |
| `Invert` | 反色 | 反转 RGB | 是 |
| `Posterize` | 色调分离 | 降低色阶的海报效果 | 是 |
| `Saturation` | 饱和度 | 调整饱和度 | 是 |
| `Sharpness` | 锐化 | 卷积锐化 | 是 |
| `Solarize` | 中途曝光 | 高于阈值的色调反转（暗房效果） | 是 |
| `Tint` | 着色 | 给画面叠加颜色 | 是 |
| `Tritone` | 三色调 | 阴影/中间调/高光三色映射 | 是 |
| `Vibrance` | 自然饱和度 | 保护肤色的饱和度调整 | 是 |

## 转场（Transitions，13）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `BarnDoors` | 对开门转场 | 沿中线分割并向两侧擦除 | 是 |
| `BlockDissolve` | 方块溶解 | 画面按网格方块随机消失 | 是 |
| `CheckerWipe` | 棋盘转场 | 以棋盘格方块淡出画面 | 是 |
| `DiamondWipe` | 菱形转场 | 以不断扩大的菱形格擦除画面 | 是 |
| `IrisWipe` | 圆形展开 | 从中心扩大的圆形转场 | 是 |
| `LinearWipe` | 线性擦除 | 沿直线柔边擦除转场 | 是 |
| `NoiseDissolve` | 噪声溶解 | 以有机噪声图案溶解画面 | 是 |
| `PagePeel` | 翻页卷角 | 像纸张一样从角落卷起 | 是 |
| `RadialWipe` | 时钟擦除 | 像时钟指针一样扫过的转场 | 是 |
| `RandomBars` | 随机条带 | 平行条带随机消失的转场 | 是 |
| `RippleWipe` | 涟漪转场 | 同心波纹扩散擦除 | 是 |
| `SliceWipe` | 切片转场 | 切成条带交替滑出 | 是 |
| `VenetianBlinds` | 百叶窗 | 百叶窗式转场 | 是 |

## 形状（Shapes，16）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `Arc` | 扇形 | 可调半径与张角的扇形/弧块 |  |
| `Circle` | 圆形 | 可调大小与柔边的圆 |  |
| `Crescent` | 新月 | 新月形状 |  |
| `Cross` | 十字 | 可调臂长、宽度与圆角的十字形 |  |
| `Ellipse` | 椭圆 | 横纵半径可调的椭圆 |  |
| `Flower` | 花瓣形 | 可调瓣数与内外径比的花形 |  |
| `Heart` | 心形 | 可调大小的心形 |  |
| `Line` | 线段 | 实线/虚线/点线 |  |
| `Parallelogram` | 平行四边形 | 可调宽高与斜切 |  |
| `Polygon` | 正多边形 | 可调边数与圆角 |  |
| `Ring` | 圆环 | 可调半径与宽度的圆环 |  |
| `RoundedRect` | 圆角矩形 | 可调圆角的矩形 |  |
| `Star` | 星形 | 尖角星形 |  |
| `Teardrop` | 水滴形 | 圆头尖尾的水滴 |  |
| `Trapezoid` | 梯形 | 上下底可调的梯形 |  |
| `Vesica` | 鱼形透镜 | 两圆相交的透镜形 |  |

## 工具（Utilities，1）

| 效果 | 中文名 | 说明 | 需要输入 |
|---|---|---|---|
| `Group` | 分组 | 组织子效果的容器，支持弹性布局 | 是 |
