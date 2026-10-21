import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShaderView, ShaderController, ShaderNode } from '@virgo/webgpu-effects';
import { BenchSide, CompareItem, claudeLayers, compareItems } from '../common/Compare';
import { ShaderPortView, shaderPortStats, PortStats } from '../common/ShaderPortView';
import { categoryLabel } from '../common/Catalog';

interface CompareParams {
  name: string;
}

type Mode = 'split' | 'claude' | 'port';

interface BenchLog {
  name: string;
  mode: string;
  claude: BenchSide;
  port: BenchSide;
}

const MODE_LABEL: Record<string, string> = { 'split': '分屏', 'claude': '仅 Claude', 'port': '仅 shaderport' };

/**
 * The same effect from both ports, with the same defaults and base: Claude (upstream engine on
 * our WebGPU/Vulkan) and shaderport (offline GLSL ES on its GLES renderer). Split top/bottom, or
 * left/right when the screen is wide (unfolded tri-fold). Single-side modes give each renderer the
 * GPU to itself for a fair FPS reading.
 */
@Entry
@Component
struct CompareDetail {
  @State index: number = 0;
  @State mode: Mode = 'split';
  @State wide: boolean = false;
  @State claude: ShaderNode[] = [];
  @State portId: string = '';
  @State claudeText: string = '';
  @State portText: string = '';
  @State claudeError: string = '';
  @State portError: string = '';
  private list: CompareItem[] = [];
  private controller: ShaderController = new ShaderController();
  private timer: number = -1;
  private firstTimer: number = -1;
  private shownAt: number = 0;
  private claudeFirst: number = 0;
  private portFirst: number = 0;
  private bench: boolean = false;
  private samples: number[][] = [];

  aboutToAppear(): void {
    const ctx = getContext(this) as common.Context;
    this.list = compareItems(ctx).filter((i: CompareItem) => i.portId !== '');
    const params = router.getParams() as CompareParams | undefined;
    const name = params?.name ?? AppStorage.get<string>('fx') ?? '';
    const m = AppStorage.get<string>('mode') ?? '';
    if (m === 'claude' || m === 'port' || m === 'split') {
      this.mode = m as Mode;
      this.bench = true;
    }
    const i = this.list.findIndex((it: CompareItem) => it.entry.name === name);
    this.show(i >= 0 ? i : 0);
    this.timer = setInterval(() => this.tick(), 500);
  }

  aboutToDisappear(): void {
    clearInterval(this.timer);
    clearInterval(this.firstTimer);
  }

  private show(i: number): void {
    const n = this.list.length;
    this.index = ((i % n) + n) % n;
    const item = this.list[this.index];
    this.claude = claudeLayers(item);
    this.portId = item.portId;
    this.claudeError = '';
    this.portError = '';
    this.shownAt = Date.now();
    this.claudeFirst = 0;
    this.portFirst = 0;
    this.samples = [];
    // Time to first presented frame, polled at frame granularity.
    clearInterval(this.firstTimer);
    this.firstTimer = setInterval(() => {
      const now = Date.now();
      if (this.claudeFirst === 0 && this.mode !== 'port' && this.controller.stats().fps > 0) this.claudeFirst = now - this.shownAt;
      if (this.portFirst === 0 && this.mode !== 'claude' && shaderPortStats().fps > 0) this.portFirst = now - this.shownAt;
      if ((this.claudeFirst > 0 || this.mode === 'port') && (this.portFirst > 0 || this.mode === 'claude') ||
        now - this.shownAt > 10000) {
        clearInterval(this.firstTimer);
      }
    }, 16);
  }

  private tick(): void {
    const c = this.mode !== 'port' ? this.controller.stats() : { fps: 0, cpuMs: 0 } as PortStats;
    const p: PortStats = this.mode !== 'claude' ? shaderPortStats() : { fps: 0, cpuMs: 0 } as PortStats;
    const now = Date.now();
    this.claudeText = `${c.fps.toFixed(0)} fps · ${c.cpuMs.toFixed(1)} ms`;
    this.portText = `${p.fps.toFixed(0)} fps · ${p.cpuMs.toFixed(1)} ms`;
    if (!this.bench) return;
    // Automated runs (scripts/compare-bench.sh): skip 2.5 s of warm-up, average the next 5 s.
    const elapsed = now - this.shownAt;
    if (elapsed > 2500 && elapsed <= 7500) this.samples.push([c.fps, c.cpuMs, p.fps, p.cpuMs]);
    if (elapsed > 7500 && this.samples.length > 0) {
      const avg = (k: number): number => this.samples.reduce((s: number, v: number[]) => s + v[k], 0) / this.samples.length;
      const claude: BenchSide = { fps: avg(0), cpuMs: avg(1), firstFrameMs: this.claudeFirst, ok: this.claudeError === '' };
      const port: BenchSide = { fps: avg(2), cpuMs: avg(3), firstFrameMs: this.portFirst, ok: this.portError === '' };
      const log: BenchLog = { name: this.list[this.index].entry.name, mode: this.mode, claude, port };
      hilog.warn(0x5348, 'bench', 'SHADERBENCH %{public}s', JSON.stringify(log));
      this.samples = [];
      this.bench = false;
    }
  }

  @Builder
  badge(text: string, isClaude: boolean, color: string) {
    // Reads the stats from state directly: @Builder value parameters do not refresh.
    Column({ space: 2 }) {
      Text(text).fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
      if (isClaude) {
        Text(this.claudeError ? this.claudeError : this.claudeText).fontSize(11)
          .fontColor(this.claudeError ? '#FFB4B4' : '#D9FFFFFF')
      } else {
        Text(this.portError ? this.portError : this.portText).fontSize(11)
          .fontColor(this.portError ? '#FFB4B4' : '#D9FFFFFF')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .borderRadius(10)
    .backgroundColor(color)
    .margin(10)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  claudePane() {
    Stack({ alignContent: Alignment.TopStart }) {
      ShaderView({
        layers: this.claude, controller: this.controller, pauseWhenHidden: false,
        onShaderError: (r: string) => {
          this.claudeError = r;
        },
      }).width('100%').height('100%')
      this.badge('Claude 转换 · WebGPU/Vulkan', true, '#B36D28D9')
    }
  }

  @Builder
  portPane() {
    Stack({ alignContent: Alignment.TopStart }) {
      ShaderPortView({
        effectId: this.portId,
        onError: (m: string) => {
          this.portError = m;
        },
      }).width('100%').height('100%')
      this.badge('shaderport · GLES 3.0', false, '#B3C2410C')
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.mode === 'claude') {
        this.claudePane()
      } else if (this.mode === 'port') {
        this.portPane()
      } else {
        Flex({ direction: this.wide ? FlexDirection.Row : FlexDirection.Column }) {
          Column() { this.claudePane() }.flexGrow(1).flexBasis(0)
          Divider().vertical(this.wide).color('#FFFFFF').strokeWidth(1)
          Column() { this.portPane() }.flexGrow(1).flexBasis(0)
        }.width('100%').height('100%')
      }

      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('‹').fontSize(26).fontColor(Color.White).width(40).height(40).textAlign(TextAlign.Center)
            .borderRadius(20).backgroundColor('#66000000').onClick(() => router.back())
          Column() {
            Text(`${this.list[this.index]?.entry.title ?? ''}  ${this.list[this.index]?.entry.name ?? ''}`)
              .fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Medium)
            Text(`${categoryLabel(this.list[this.index]?.entry.category ?? '')} · 两边都有 ${this.index + 1}/${this.list.length}` +
              (this.list[this.index]?.portBase ? ' · 底图 Plasma' : ''))
              .fontSize(11).fontColor('#B3FFFFFF')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')
        Row({ space: 8 }) {
          Text('上一个').fontSize(13).fontColor(Color.White).padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(16).backgroundColor('#66000000').onClick(() => this.show(this.index - 1))
          ForEach(['split', 'claude', 'port'], (m: string) => {
            Text(MODE_LABEL[m]).fontSize(12)
              .fontColor(this.mode === m ? '#0B0B10' : Color.White)
              .backgroundColor(this.mode === m ? '#FFFFFF' : '#66000000')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 }).borderRadius(16)
              .onClick(() => {
                this.mode = m as Mode;
                this.shownAt = Date.now();
              })
          }, (m: string) => m)
          Blank()
          Text('下一个').fontSize(13).fontColor(Color.White).padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(16).backgroundColor('#66000000').onClick(() => this.show(this.index + 1))
        }.width('100%')
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 24 })
      .linearGradient({ angle: 180, colors: [['#00000000', 0], ['#AA000000', 0.4], ['#DD000000', 1]] })
    }
    .width('100%').height('100%')
    .backgroundColor('#000000')
    .onAreaChange((_: Area, a: Area) => {
      this.wide = Number(a.width) > Number(a.height) * 0.8;
    })
  }
}
