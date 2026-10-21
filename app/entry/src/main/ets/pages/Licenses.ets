import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

/** License texts of this app and everything it bundles (rawfile/licenses.txt, written by scripts/build.sh). */
@Entry
@Component
struct Licenses {
  @State text: string = '';

  aboutToAppear(): void {
    try {
      const bytes = (getContext(this) as common.Context).resourceManager.getRawFileContentSync('licenses.txt');
      this.text = util.TextDecoder.create('utf-8').decodeToString(bytes);
    } catch (e) {
      this.text = 'licenses.txt missing';
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹').fontSize(26).fontColor(Color.White).onClick(() => router.back())
        Text('开源许可').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
      }
      .width('100%').padding({ left: 16, right: 16, top: 40, bottom: 10 })
      Scroll() {
        Text(this.text).fontSize(11).fontColor('#CCFFFFFF').fontFamily('monospace')
          .padding({ left: 16, right: 16, bottom: 40 })
      }
      .layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor('#0B0B10')
  }
}
