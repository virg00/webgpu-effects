import { router } from '@kit.ArkUI';
import { ShaderView, ShaderNode, LinearGradient } from '@virg00/webgpu-effects';
import { loadCatalog, previewLayers, CatalogEntry } from '../common/Catalog';
import { common } from '@kit.AbilityKit';

/** Single-effect page for automated checks: `aa start ... --ps page Test --ps fx <Name>`. */
@Entry
@Component
struct Test {
  @State layers: ShaderNode[] = [LinearGradient({ colorA: '#0f172a', colorB: '#7c3aed' })];
  @State status: string = 'starting';

  aboutToAppear(): void {
    const fx = AppStorage.get<string>('fx') ?? '';
    if (fx) {
      const e = loadCatalog(getContext(this) as common.Context).find((c: CatalogEntry) => c.name === fx);
      if (e) this.layers = previewLayers(e, 'fx');
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ShaderView({
        layers: this.layers,
        onReady: () => { this.status = 'ready'; },
        onShaderError: (r: string) => { this.status = `error: ${r}`; },
      }).width('100%').height('100%')
      Text(this.status).fontColor(Color.White).fontSize(12).margin({ top: 40, left: 12 }).id('status')
    }.width('100%').height('100%').backgroundColor('#000000')
  }
}
