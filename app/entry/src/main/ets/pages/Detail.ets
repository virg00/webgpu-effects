import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ShaderView, ShaderController, ShaderNode, Position } from '@virgo/webgpu-effects';
import {
  CatalogEntry, CatalogProp, PropOption, categoryLabel, isInteractive, loadCatalog, previewLayers,
} from '../common/Catalog';

interface DetailParams {
  name: string;
  filter?: string;
}

const SWATCHES: string[] = [
  '#ffffff', '#000000', '#ff3b5c', '#ff9f1c', '#ffe066', '#2ec4b6', '#3a86ff', '#8338ec', '#e04b9e', '#1aff00',
];

const FX_ID = 'fx';

/** One effect full screen; prev/next walk the menu order, the sheet edits its props live. */
@Entry
@Component
struct Detail {
  @State entry: CatalogEntry | undefined = undefined;
  @State index: number = 0;
  @State values: Record<string, Object> = {};
  @State layers: ShaderNode[] = [];
  @State status: string = '';
  @State showProps: boolean = false;
  @State showHint: boolean = false;
  private list: CatalogEntry[] = [];
  private controller: ShaderController = new ShaderController();

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams | undefined;
    const all = loadCatalog(getContext(this) as common.Context);
    const filter = params?.filter ?? '推荐';
    this.list = filter === '推荐' ? all : all.filter((e: CatalogEntry) => e.category === filter);
    const name = params?.name ?? AppStorage.get<string>('fx') ?? '';
    const i = this.list.findIndex((e: CatalogEntry) => e.name === name);
    this.show(i >= 0 ? i : 0);
  }

  private show(i: number): void {
    const n = this.list.length;
    this.index = ((i % n) + n) % n;
    const e = this.list[this.index];
    this.entry = e;
    const values: Record<string, Object> = {};
    e.props.forEach((p: CatalogProp) => {
      if (p.default !== null && p.default !== undefined) values[p.name] = p.default;
    });
    this.values = values;
    this.status = '';
    this.layers = previewLayers(e, FX_ID);
    this.showHint = isInteractive(e.name);
    if (this.showHint) {
      setTimeout(() => {
        this.showHint = false;
      }, 3000);
    }
  }

  private set(name: string, value: Object): void {
    const next: Record<string, Object> = {};
    Object.keys(this.values).forEach((k: string) => {
      next[k] = this.values[k];
    });
    next[name] = value;
    this.values = next;
    const change: Record<string, Object> = {};
    change[name] = value;
    this.controller.update(FX_ID, change);
  }

  private num(name: string, def: number): number {
    const v = this.values[name];
    return typeof v === 'number' ? v as number : def;
  }

  private str(name: string): string {
    const v = this.values[name];
    return typeof v === 'string' ? v as string : '';
  }

  private pos(name: string): Position {
    const v = this.values[name] as Position;
    return v && typeof v.x === 'number' ? v : { x: 0.5, y: 0.5 } as Position;
  }

  /** The value shown next to a control (read here, not passed in: @Builder value args don't refresh). */
  private display(p: CatalogProp): string {
    if (p.kind === 'color') return this.str(p.name);
    if (p.kind === 'position') return `${this.pos(p.name).x.toFixed(2)}, ${this.pos(p.name).y.toFixed(2)}`;
    if (p.kind === 'range' || p.kind === 'hidden') {
      return this.num(p.name, 0).toFixed(p.step !== undefined && p.step >= 1 ? 0 : 2);
    }
    return '';
  }

  @Builder
  label(p: CatalogProp) {
    Row() {
      Text(p.label).fontSize(13).fontColor('#E6FFFFFF').layoutWeight(1)
      Text(this.display(p)).fontSize(12).fontColor('#99FFFFFF')
    }.width('100%')
  }

  @Builder
  control(p: CatalogProp) {
    Column({ space: 6 }) {
      if (p.kind === 'range' || (p.kind === 'hidden' && typeof p.default === 'number')) {
        this.label(p)
        Slider({
          value: this.num(p.name, 0),
          min: p.min ?? 0,
          max: p.max ?? Math.max(1, this.num(p.name, 0) * 2),
          step: p.step ?? 0.01,
        })
          .trackColor('#33FFFFFF').selectedColor('#8B5CF6').blockColor(Color.White)
          .onChange((v: number) => this.set(p.name, v))
      } else if (p.kind === 'color') {
        this.label(p)
        Row({ space: 8 }) {
          ForEach(SWATCHES, (c: string) => {
            Circle()
              .width(24).height(24).fill(c)
              .stroke(this.str(p.name).toLowerCase() === c ? '#FFFFFF' : '#33FFFFFF')
              .strokeWidth(this.str(p.name).toLowerCase() === c ? 3 : 1)
              .onClick(() => this.set(p.name, c))
          }, (c: string) => c)
        }
      } else if (p.kind === 'select' && p.options) {
        this.label(p)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(p.options, (o: PropOption) => {
            Text(o.label)
              .fontSize(12)
              .fontColor(this.values[p.name] === o.value ? '#0B0B10' : '#E6FFFFFF')
              .backgroundColor(this.values[p.name] === o.value ? '#FFFFFF' : '#1FFFFFFF')
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .margin({ right: 6, bottom: 6 })
              .onClick(() => this.set(p.name, o.value))
          }, (o: PropOption) => `${o.value}`)
        }
      } else if (p.kind === 'checkbox') {
        Row() {
          Text(p.label).fontSize(13).fontColor('#E6FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.values[p.name] === true })
            .selectedColor('#8B5CF6')
            .onChange((on: boolean) => this.set(p.name, on))
        }.width('100%')
      } else if (p.kind === 'position') {
        this.label(p)
        Slider({ value: this.pos(p.name).x, min: 0, max: 1, step: 0.01 })
          .trackColor('#33FFFFFF').selectedColor('#8B5CF6').blockColor(Color.White)
          .onChange((v: number) => this.set(p.name, { x: v, y: this.pos(p.name).y } as Position))
        Slider({ value: this.pos(p.name).y, min: 0, max: 1, step: 0.01 })
          .trackColor('#33FFFFFF').selectedColor('#8B5CF6').blockColor(Color.White)
          .onChange((v: number) => this.set(p.name, { x: this.pos(p.name).x, y: v } as Position))
      } else if (p.kind === 'text' || p.kind === 'font-family') {
        this.label(p)
        TextInput({ text: this.str(p.name) })
          .fontColor(Color.White).backgroundColor('#1FFFFFFF')
          .onChange((v: string) => this.set(p.name, v))
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  roundButton(icon: string, action: () => void) {
    Text(icon)
      .fontSize(22).fontColor(Color.White).textAlign(TextAlign.Center)
      .width(44).height(44).borderRadius(22)
      .backgroundColor('#59000000')
      .onClick(action)
  }

  @Builder
  propsSheet() {
    Column() {
      Row() {
        Text('参数').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White).layoutWeight(1)
        Text('收起').fontSize(13).fontColor('#B3FFFFFF').onClick(() => {
          this.showProps = false;
        })
      }.width('100%').margin({ bottom: 4 })
      Scroll() {
        Column() {
          if (this.entry) {
            ForEach(this.entry.props, (p: CatalogProp) => {
              this.control(p)
            }, (p: CatalogProp) => `${this.entry?.name}.${p.name}`)
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('45%')
    .padding({ left: 20, right: 20, top: 14, bottom: 20 })
    .backgroundColor('#E6101016')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      ShaderView({
        layers: this.layers,
        controller: this.controller,
        onShaderError: (r: string) => {
          this.status = r;
        },
      })
        .width('100%').height('100%')

      // Top bar
      Row({ space: 10 }) {
        this.roundButton('‹', () => router.back())
        Blank()
        if (this.status) {
          Text(`GPU: ${this.status}`).fontSize(11).fontColor('#FFB4B4')
            .backgroundColor('#99000000').padding(6).borderRadius(6)
        }
        Text(`${this.index + 1} / ${this.list.length}`)
          .fontSize(12).fontColor('#E6FFFFFF')
          .backgroundColor('#59000000').borderRadius(14)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 40 })
      .position({ x: 0, y: 0 })

      if (this.showHint) {
        Text('用手指在屏幕上滑动试试')
          .fontSize(14).fontColor(Color.White)
          .backgroundColor('#99000000').borderRadius(18)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .position({ x: '50%', y: '45%' })
          .translate({ x: '-50%' })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.showProps) {
        this.propsSheet()
      } else if (this.entry) {
        // Bottom bar: name, description, prev / params / next
        Column({ space: 10 }) {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(this.entry.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
              Text(this.entry.name).fontSize(12).fontColor('#B3FFFFFF')
            }
            Text(`${categoryLabel(this.entry.category)} · ${this.entry.zh}`)
              .fontSize(13).fontColor('#D9FFFFFF').maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          Row({ space: 12 }) {
            this.roundButton('‹', () => this.show(this.index - 1))
            Text('调整参数')
              .fontSize(14).fontColor(Color.White).textAlign(TextAlign.Center)
              .height(44).layoutWeight(1).borderRadius(22)
              .backgroundColor('#598B5CF6')
              .onClick(() => {
                this.showProps = true;
              })
            this.roundButton('›', () => this.show(this.index + 1))
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 28 })
        .linearGradient({ angle: 180, colors: [['#00000000', 0], ['#99000000', 0.45], ['#CC000000', 1]] })
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#000000')
  }
}
