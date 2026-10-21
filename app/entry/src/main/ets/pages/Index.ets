import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ShaderView, ShaderNode } from '@virg00/webgpu-effects';
import { CatalogEntry, CATEGORIES, categoryLabel, isInteractive, loadCatalog, previewLayers } from '../common/Catalog';

const ALL = '推荐';

class EntrySource implements IDataSource {
  private items: CatalogEntry[] = [];
  private listeners: DataChangeListener[] = [];

  set(items: CatalogEntry[]): void {
    this.items = items;
    this.listeners.forEach((l: DataChangeListener) => l.onDataReloaded());
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): CatalogEntry {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((l: DataChangeListener) => l !== listener);
  }
}

/**
 * The effect menu: every effect, best first, with a thumbnail rendered on a real phone.
 * Tapping one opens it full screen (Detail), where you can step through the same order.
 */
@Entry
@Component
struct Index {
  @State filter: string = ALL;
  @State hero: ShaderNode[] = [];
  @State heroName: string = '';
  private all: CatalogEntry[] = [];
  private source: EntrySource = new EntrySource();

  aboutToAppear(): void {
    this.all = loadCatalog(getContext(this) as common.Context);
    this.select(ALL);
    const top = this.all[0];
    this.hero = previewLayers(top, 'hero');
    this.heroName = top.title;
  }

  private visible(): CatalogEntry[] {
    return this.filter === ALL ? this.all : this.all.filter((e: CatalogEntry) => e.category === this.filter);
  }

  private select(c: string): void {
    this.filter = c;
    this.source.set(this.visible());
  }

  private open(e: CatalogEntry): void {
    router.pushUrl({ url: 'pages/Detail', params: { name: e.name, filter: this.filter } });
  }

  @Builder
  header() {
    Stack({ alignContent: Alignment.BottomStart }) {
      ShaderView({ layers: this.hero, interactive: false })
        .width('100%').height('100%')
      Column({ space: 2 }) {
        Text('WebGPU Effects').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text(`${this.all.length} 个 GPU 实时特效 · HarmonyOS`).fontSize(13).fontColor('#D9FFFFFF')
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, bottom: 16 })
      .hitTestBehavior(HitTestMode.Transparent)
      Text(`No.1 ${this.heroName}`)
        .fontSize(11).fontColor('#B3FFFFFF')
        .backgroundColor('#33000000').borderRadius(10)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .position({ right: 14, bottom: 18 })
    }
    .width('100%').height(210)
    .onClick(() => this.open(this.all[0]))
  }

  @Builder
  compareBar() {
    Row({ space: 10 }) {
      Row({ space: 6 }) {
        Text('⇆').fontSize(16).fontColor('#C4B5FD')
        Column() {
          Text('对比 shaderport').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Medium)
          Text('两种移植分屏对比').fontSize(11).fontColor('#99FFFFFF')
        }.alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1).padding(10).borderRadius(12).backgroundColor('#14FFFFFF')
      .onClick(() => router.pushUrl({ url: 'pages/CompareMenu' }))
      Row({ space: 6 }) {
        Text('▤').fontSize(16).fontColor('#86EFAC')
        Column() {
          Text('对比分析').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Medium)
          Text('真机实测与优劣').fontSize(11).fontColor('#99FFFFFF')
        }.alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1).padding(10).borderRadius(12).backgroundColor('#14FFFFFF')
      .onClick(() => router.pushUrl({ url: 'pages/Analysis' }))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12 })
  }

  @Builder
  chips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach([ALL, ...CATEGORIES], (c: string) => {
          Text(c === ALL ? ALL : categoryLabel(c))
            .fontSize(13)
            .fontColor(this.filter === c ? '#0B0B10' : '#E6FFFFFF')
            .backgroundColor(this.filter === c ? '#FFFFFF' : '#1FFFFFFF')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .onClick(() => this.select(c))
        }, (c: string) => c)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: 12, bottom: 4 })
  }

  @Builder
  row(e: CatalogEntry) {
    Row({ space: 12 }) {
      Stack() {
        Image($rawfile(`thumbs/${e.name}.jpg`))
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.background'))
      }
      .width(66).height(88).borderRadius(10).clip(true).backgroundColor('#1A1A22')

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(`${e.rank}`)
            .fontSize(11).fontColor('#99FFFFFF').fontWeight(FontWeight.Medium)
          Text(e.title).fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Medium)
          Text(e.name).fontSize(11).fontColor('#80FFFFFF').maxLines(1).layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        Text(e.zh)
          .fontSize(13).fontColor('#B3FFFFFF')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(categoryLabel(e.category))
            .fontSize(10).fontColor('#CCFFFFFF')
            .backgroundColor('#1FFFFFFF').borderRadius(6)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          if (isInteractive(e.name)) {
            Text('可触摸')
              .fontSize(10).fontColor('#0B0B10')
              .backgroundColor('#8BE9FD').borderRadius(6)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => this.open(e))
  }

  build() {
    Column() {
      List() {
        ListItem() {
          Column() {
            this.header()
            this.compareBar()
            this.chips()
          }
        }
        LazyForEach(this.source, (e: CatalogEntry) => {
          ListItem() {
            this.row(e)
          }
        }, (e: CatalogEntry) => e.name)
      }
      .width('100%').layoutWeight(1)
      .cachedCount(6)
      .scrollBar(BarState.Off)
      .divider({ strokeWidth: 0.5, color: '#14FFFFFF', startMargin: 94, endMargin: 16 })
    }
    .width('100%').height('100%')
    .backgroundColor('#0B0B10')
  }
}
