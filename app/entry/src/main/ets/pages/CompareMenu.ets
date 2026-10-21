import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { EffectSummary } from '@quizzyjoy/shaderport';
import { CompareItem, compareItems, portOnly } from '../common/Compare';
import { categoryLabel } from '../common/Catalog';

class ItemSource implements IDataSource {
  private items: CompareItem[] = [];
  private listeners: DataChangeListener[] = [];

  set(items: CompareItem[]): void {
    this.items = items;
    this.listeners.forEach((l: DataChangeListener) => l.onDataReloaded());
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): CompareItem {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((l: DataChangeListener) => l !== listener);
  }
}

const TABS: string[] = ['全部', '两边都有', '仅 Claude', '仅 shaderport'];

/** Every effect across both ports: shared ones open the split-screen comparison. */
@Entry
@Component
struct CompareMenu {
  @State tab: string = TABS[0];
  @State both: number = 0;
  @State claudeOnly: number = 0;
  @State portOnlyCount: number = 0;
  private all: CompareItem[] = [];
  private portExtra: EffectSummary[] = [];
  private source: ItemSource = new ItemSource();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.Context;
    this.all = compareItems(ctx);
    this.portExtra = portOnly(ctx);
    this.both = this.all.filter((i: CompareItem) => i.portId !== '').length;
    this.claudeOnly = this.all.length - this.both;
    this.portOnlyCount = this.portExtra.length;
    this.select(TABS[0]);
  }

  private select(tab: string): void {
    this.tab = tab;
    let list = this.all;
    if (tab === '两边都有') list = this.all.filter((i: CompareItem) => i.portId !== '');
    else if (tab === '仅 Claude') list = this.all.filter((i: CompareItem) => i.portId === '');
    else if (tab === '仅 shaderport') list = [];
    this.source.set(list);
  }

  private open(i: CompareItem): void {
    if (i.portId) router.pushUrl({ url: 'pages/CompareDetail', params: { name: i.entry.name } });
    else router.pushUrl({ url: 'pages/Detail', params: { name: i.entry.name } });
  }

  @Builder
  stat(n: number, label: string, color: string) {
    Column({ space: 2 }) {
      Text(`${n}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor('#B3FFFFFF')
    }.layoutWeight(1)
  }

  @Builder
  header() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('‹').fontSize(26).fontColor(Color.White).onClick(() => router.back())
        Text('Claude vs shaderport').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
        Text('分析报告 ›').fontSize(13).fontColor('#C4B5FD')
          .onClick(() => router.pushUrl({ url: 'pages/Analysis' }))
      }.width('100%')
      Text('同一个上游效果库（shaders 4.0.4）的两种鸿蒙移植：Claude 在运行时直接跑上游引擎并自带 WebGPU（Vulkan）；shaderport 把效果离线转成 GLSL ES 3.00，由 GLES 渲染器绘制。')
        .fontSize(12).fontColor('#B3FFFFFF')
      Row() {
        this.stat(this.both, '两边都有 · 可分屏对比', '#FFFFFF')
        this.stat(this.claudeOnly, '仅 Claude 转换', '#C4B5FD')
        this.stat(this.portOnlyCount, '仅 shaderport', '#FDBA74')
      }.width('100%')
      Scroll() {
        Row({ space: 8 }) {
          ForEach(TABS, (t: string) => {
            Text(t).fontSize(13)
              .fontColor(this.tab === t ? '#0B0B10' : '#E6FFFFFF')
              .backgroundColor(this.tab === t ? '#FFFFFF' : '#1FFFFFFF')
              .borderRadius(16).padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .onClick(() => this.select(t))
          }, (t: string) => t)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      if (this.tab === '仅 shaderport') {
        Text(this.portOnlyCount === 0 ?
          'shaderport 的 48 个效果全部来自同一上游库，名称都能在 Claude 版中找到对应，因此没有 shaderport 独有的效果。' :
          this.portExtra.map((e: EffectSummary) => e.name).join('、'))
          .fontSize(13).fontColor('#D9FFFFFF').padding({ top: 8 })
      }
    }
    .padding({ left: 16, right: 16, top: 40, bottom: 8 })
  }

  @Builder
  row(i: CompareItem) {
    Row({ space: 10 }) {
      Image($rawfile(i.portId ? `cmp-thumbs/${i.entry.name}.jpg` : `thumbs/${i.entry.name}.jpg`))
        .width(56).height(76).borderRadius(8).objectFit(ImageFit.Cover).backgroundColor('#1A1A22')
      if (i.portId) {
        Image($rawfile(`port-thumbs/${i.portId}.jpg`))
          .width(56).height(76).borderRadius(8).objectFit(ImageFit.Cover).backgroundColor('#1A1A22')
      }
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(i.entry.title).fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Medium)
          Text(i.entry.name).fontSize(11).fontColor('#80FFFFFF')
        }
        Text(i.entry.zh).fontSize(12).fontColor('#B3FFFFFF').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(categoryLabel(i.entry.category)).fontSize(10).fontColor('#CCFFFFFF')
            .backgroundColor('#1FFFFFFF').borderRadius(6).padding({ left: 6, right: 6, top: 2, bottom: 2 })
          if (i.portId) {
            Text('两边都有 · 点开分屏对比').fontSize(10).fontColor('#0B0B10')
              .backgroundColor('#FFFFFF').borderRadius(6).padding({ left: 6, right: 6, top: 2, bottom: 2 })
          } else {
            Text('仅 Claude 转换').fontSize(10).fontColor('#0B0B10')
              .backgroundColor('#C4B5FD').borderRadius(6).padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 7, bottom: 7 })
    .onClick(() => this.open(i))
  }

  build() {
    List() {
      ListItem() { this.header() }
      LazyForEach(this.source, (i: CompareItem) => {
        ListItem() { this.row(i) }
      }, (i: CompareItem) => i.entry.name)
    }
    .width('100%').height('100%')
    .cachedCount(6)
    .scrollBar(BarState.Off)
    .divider({ strokeWidth: 0.5, color: '#14FFFFFF', startMargin: 16, endMargin: 16 })
    .backgroundColor('#0B0B10')
  }
}
