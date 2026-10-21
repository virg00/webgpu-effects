import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import BuildProfile from 'BuildProfile';
import { initShaders, setDebug } from '@virg00/webgpu-effects';

export default class EntryAbility extends UIAbility {
  private page: string = 'pages/Index';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initShaders(this.context);
    // Engine diagnostics (GPU errors, WGSL failures) go to hilog in debug builds.
    setDebug(BuildProfile.DEBUG);
    // Debug builds accept `--ps page Test --ps fx <Effect>` for automated checks.
    const params = want.parameters ?? {};
    if (BuildProfile.DEBUG && typeof params['page'] === 'string') {
      this.page = `pages/${params['page'] as string}`;
      AppStorage.setOrCreate('fx', (params['fx'] as string) ?? '');
      AppStorage.setOrCreate('mode', (params['mode'] as string) ?? '');
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // A showcase: keep the screen on while effects are displayed.
    windowStage.getMainWindowSync().setWindowKeepScreenOn(true).catch(() => {});
    windowStage.loadContent(this.page);
  }
}
