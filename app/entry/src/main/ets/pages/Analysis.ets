import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AnimatedCheck, BenchRow, CompareReport, FidelityItem, ReportRow, loadReport } from '../common/Compare';

/** The written comparison of the two ports, with the per-effect measurements from a real phone. */
@Entry
@Component
struct Analysis {
  @State report: CompareReport | null = null;

  aboutToAppear(): void {
    this.report = loadReport(getContext(this) as common.Context);
  }

  private avg(f: (r: BenchRow) => number): number {
    const rows = this.report?.bench ?? [];
    const ok = rows.filter((r: BenchRow) => r.claude.ok && r.port.ok);
    return ok.length ? ok.reduce((s: number, r: BenchRow) => s + f(r), 0) / ok.length : 0;
  }

  @Builder
  card(value: string, label: string, color: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(22).maxFontSize(22).minFontSize(12).maxLines(1).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor('#B3FFFFFF').textAlign(TextAlign.Center)
    }
    .layoutWeight(1).padding(10).borderRadius(12).backgroundColor('#14FFFFFF')
  }

  @Builder
  tableRow(r: ReportRow) {
    Column({ space: 6 }) {
      Text(r.topic).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('Claude').fontSize(10).fontColor('#C4B5FD')
          Text(r.claude).fontSize(12).fontColor('#E6FFFFFF')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column({ space: 2 }) {
          Text('shaderport').fontSize(10).fontColor('#FDBA74')
          Text(r.port).fontSize(12).fontColor('#E6FFFFFF')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.alignItems(VerticalAlign.Top)
      Text(r.verdict).fontSize(12).fontColor('#86EFAC')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%').padding(12).borderRadius(12).backgroundColor('#0FFFFFFF')
  }

  @Builder
  bar(value: number, max: number, color: string) {
    Stack({ alignContent: Alignment.Start }) {
      Row().width('100%').height(6).borderRadius(3).backgroundColor('#14FFFFFF')
      Row().width(`${Math.min(100, max > 0 ? value / max * 100 : 0)}%`).height(6).borderRadius(3).backgroundColor(color)
    }.layoutWeight(1)
  }

  @Builder
  triplet(f: FidelityItem) {
    Column({ space: 6 }) {
      Text(f.name).fontSize(13).fontColor(Color.White)
      Row({ space: 6 }) {
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${f.name}-ref.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text('上游原版').fontSize(10).fontColor('#B3FFFFFF')
        }.layoutWeight(1)
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${f.name}-claude.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text(`Claude · 差异 ${f.claude.toFixed(1)}%`).fontSize(10).fontColor('#C4B5FD')
        }.layoutWeight(1)
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${f.name}-port.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text(`shaderport · 差异 ${f.port.toFixed(1)}%`).fontSize(10).fontColor('#FDBA74')
        }.layoutWeight(1)
      }.width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%').padding({ top: 6, bottom: 10 })
  }

  @Builder
  animatedRow(a: AnimatedCheck) {
    Column({ space: 6 }) {
      Text(a.name).fontSize(13).fontColor(Color.White)
      Row({ space: 6 }) {
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${a.name}-ref.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text('上游原版').fontSize(10).fontColor('#B3FFFFFF')
        }.layoutWeight(1)
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${a.name}-claude.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text(a.claude).fontSize(10).fontColor('#C4B5FD')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Image($rawfile(`fidelity/${a.name}-port.jpg`)).width('100%').aspectRatio(0.77).borderRadius(6)
          Text(a.port).fontSize(10).fontColor('#FDBA74')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%').padding({ top: 6, bottom: 10 })
  }

  @Builder
  benchRow(b: BenchRow) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(b.name).fontSize(12).fontColor(Color.White)
        if (b.base) {
          Text('底图 Plasma').fontSize(9).fontColor('#99FFFFFF')
        }
        Blank()
        if (b.diffPct !== undefined && b.diffPct !== null && !b.animated) {
          Text(`画面差异 ${b.diffPct.toFixed(1)}%`).fontSize(10).fontColor('#99FFFFFF')
        } else if (b.animated) {
          Text('动画').fontSize(10).fontColor('#66FFFFFF')
        }
      }.width('100%')
      Row({ space: 6 }) {
        Text('C').fontSize(10).fontColor('#C4B5FD').width(10)
        this.bar(b.claude.fpsTouch ?? b.claude.fps, 120, '#8B5CF6')
        Text(b.claude.ok ? `${(b.claude.fpsTouch ?? b.claude.fps).toFixed(0)} fps ${b.claude.cpuMs.toFixed(1)}ms` : '失败')
          .fontSize(10).fontColor('#B3FFFFFF').width(92).textAlign(TextAlign.End)
      }
      Row({ space: 6 }) {
        Text('S').fontSize(10).fontColor('#FDBA74').width(10)
        this.bar(b.port.fpsTouch ?? b.port.fps, 120, '#F97316')
        Text(b.port.ok ? `${(b.port.fpsTouch ?? b.port.fps).toFixed(0)} fps ${b.port.cpuMs.toFixed(1)}ms` : '失败')
          .fontSize(10).fontColor('#B3FFFFFF').width(92).textAlign(TextAlign.End)
      }
    }
    .alignItems(HorizontalAlign.Start).width('100%').padding({ top: 6, bottom: 6 })
    .onClick(() => router.pushUrl({ url: 'pages/CompareDetail', params: { name: b.name } }))
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Text('‹').fontSize(26).fontColor(Color.White).onClick(() => router.back())
          Text('对比分析').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
        }.width('100%')
        if (!this.report) {
          Text('还没有测量数据（rawfile/compare-report.json）。').fontColor('#B3FFFFFF')
        } else {
          Text(`${this.report.device} · ${this.report.date}`).fontSize(12).fontColor('#99FFFFFF')
          if (this.report.fidelity) {
            Row({ space: 8 }) {
              this.card(`${this.report.fidelity.claudeAvg.toFixed(2)}% : ${this.report.fidelity.portAvg.toFixed(1)}%`,
                `与上游原版的画面差异\n（${this.report.fidelity.count} 个静态效果，越小越好）`, '#86EFAC')
              this.card(`${this.report.fidelity.claudeClose} : ${this.report.fidelity.portClose}`,
                `差异 < 3% 的效果数\n（共 ${this.report.fidelity.count} 个）`, '#86EFAC')
            }.width('100%')
          }
          Row({ space: 8 }) {
            this.card('199 : 48', '效果数量\nClaude : shaderport', '#FFFFFF')
            this.card(this.report.touchFps ?
              `${this.report.touchFps.claude.toFixed(0)} : ${this.report.touchFps.port.toFixed(0)}` :
              `${this.avg((r: BenchRow) => r.claude.fps).toFixed(0)} : ${this.avg((r: BenchRow) => r.port.fps).toFixed(0)}`,
              this.report.touchFps ? '平均 FPS（触摸时 120Hz）\n静止时两边都是 60' : '共同效果平均 FPS\n（单独全屏实测）', '#86EFAC')
            this.card(`${this.avg((r: BenchRow) => r.claude.cpuMs).toFixed(1)} : ${this.avg((r: BenchRow) => r.port.cpuMs).toFixed(1)}`,
              '每帧 CPU 耗时 ms', '#FDE68A')
          }.width('100%')
          Row({ space: 8 }) {
            this.card(`${(this.avg((r: BenchRow) => r.claude.pssKb ?? 0) / 1024).toFixed(0)} : ${(this.avg((r: BenchRow) => r.port.pssKb ?? 0) / 1024).toFixed(0)}`,
              '进程内存 MB（PSS）', '#93C5FD')
            this.card('10.5 : 1.0', '库体积 MB\n（arm64 运行时必需）', '#FCA5A5')
            this.card(`${this.avg((r: BenchRow) => r.claude.firstFrameMs).toFixed(0)} : ${this.avg((r: BenchRow) => r.port.firstFrameMs).toFixed(0)}`,
              '页面到首帧 ms', '#F0ABFC')
          }.width('100%')
          Column({ space: 6 }) {
            ForEach(this.report.summary, (s: string) => {
              Text(`• ${s}`).fontSize(13).fontColor('#E6FFFFFF')
            }, (s: string) => s)
          }.alignItems(HorizontalAlign.Start).width('100%')
          Text('逐项对比').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Color.White)
          ForEach(this.report.rows, (r: ReportRow) => {
            this.tableRow(r)
          }, (r: ReportRow) => r.topic)
          if (this.report.fidelity) {
            Text('与上游原版逐图对比').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Color.White)
            Text('原版：在 Mac 浏览器里用 WebGPU 直接运行上游 shaders 4.0.4、按手机视图同样的宽高比截图；三张图都是视图中部参与比较的同一区域（避开页面上的标签和按钮）。数字是与原版的平均像素差异。')
              .fontSize(12).fontColor('#99FFFFFF')
            ForEach(this.report.fidelity.items, (f: FidelityItem) => {
              this.triplet(f)
            }, (f: FidelityItem) => f.name)
          }
          if (this.report.animatedChecks) {
            Text('动画类效果人工核对').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Color.White)
            Text('两边时钟不同步，无法逐像素比较；截取各自某一时刻，与原版对照构图、方向与是否正常出图。')
              .fontSize(12).fontColor('#99FFFFFF')
            ForEach(this.report.animatedChecks, (a: AnimatedCheck) => {
              this.animatedRow(a)
            }, (a: AnimatedCheck) => a.name)
          }
          Text(`共同效果性能（${this.report.bench.length} 个，各自单独全屏渲染 5 秒取平均；帧率为触摸时 120Hz 下的数值，CPU 为静止时；点一行进入分屏对比）`)
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          Column() {
            ForEach(this.report.bench, (b: BenchRow) => {
              this.benchRow(b)
            }, (b: BenchRow) => b.name)
          }.width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 40, bottom: 40 })
    }
    .width('100%').height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#0B0B10')
  }
}
