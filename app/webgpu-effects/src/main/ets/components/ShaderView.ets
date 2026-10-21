import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { ShaderHost, initShaders, FrameStats } from '../engine/host';
import { ShaderNode, PresetConfig, ColorSpaceMode, ToneMapping } from './types';

/** Imperative handle for a ShaderView: live prop updates without rebuilding the layer tree. */
export class ShaderController {
  host: ShaderHost | null = null;

  /** Changes props of the layer with the given id (set `id` on the layer to target it). */
  update(id: string, props: Record<string, Object>): void {
    this.host?.update(id, props);
  }

  pause(): void {
    this.host?.setPaused(true);
  }

  /** Presented FPS over the last second and smoothed CPU time per frame. */
  stats(): FrameStats {
    return this.host ? this.host.stats() : { fps: 0, cpuMs: 0 };
  }

  resume(): void {
    this.host?.setPaused(false);
  }
}

class SurfaceController extends XComponentController {
  onCreated: (surfaceId: string) => void = () => {};
  onDestroyed: () => void = () => {};

  onSurfaceCreated(surfaceId: string): void {
    this.onCreated(surfaceId);
  }

  onSurfaceDestroyed(surfaceId: string): void {
    this.onDestroyed();
  }
}

let contextInstalled = false;

/**
 * Renders a stack of shader layers with the GPU.
 *
 * ```ts
 * ShaderView({ layers: [LinearGradient({ colorA: '#0f172a', colorB: '#7c3aed' }), CursorTrail()] })
 *   .width('100%').height(256)
 * ```
 */
@Component
export struct ShaderView {
  /** Layers, evaluated top to bottom and blended on the GPU. */
  @Prop @Watch('onLayersChange') layers: ShaderNode[] = [];
  /** Alternative to `layers`: a preset exported from the shaders.com editor. */
  @Prop @Watch('onPresetChange') preset: PresetConfig | undefined = undefined;
  /** Stops the animation loop; the last frame stays on screen. */
  @Prop @Watch('onPausedChange') paused: boolean = false;
  /** Forward touches to cursor-driven effects. */
  interactive: boolean = true;
  /** Pause automatically while the view is scrolled out of sight. */
  pauseWhenHidden: boolean = true;
  colorSpace: ColorSpaceMode = 'p3-linear';
  toneMapping: ToneMapping = 'linear';
  controller: ShaderController = new ShaderController();
  onReady: () => void = () => {};
  onShaderError: (reason: string) => void = () => {};

  private surface: SurfaceController = new SurfaceController();
  private host: ShaderHost | null = null;
  private hidden: boolean = false;

  aboutToAppear(): void {
    if (!contextInstalled) {
      contextInstalled = true;
      initShaders(getContext(this) as common.Context);
    }
    this.host = new ShaderHost({
      colorSpace: this.colorSpace,
      toneMapping: this.toneMapping,
      onReady: () => this.onReady(),
      onError: (reason: string) => this.onShaderError(reason),
    });
    this.controller.host = this.host;
    this.pushTree();
    this.host.setPaused(this.paused);
    this.updateWindow();
    this.surface.onCreated = (id: string) => this.host?.attach(id);
    this.surface.onDestroyed = () => this.host?.detach();
  }

  aboutToDisappear(): void {
    this.host?.dispose();
    this.host = null;
    this.controller.host = null;
  }

  onLayersChange(): void {
    this.pushTree();
  }

  onPresetChange(): void {
    this.pushTree();
  }

  onPausedChange(): void {
    this.host?.setPaused(this.paused || this.hidden);
  }

  private pushTree(): void {
    if (!this.host) return;
    if (this.preset) this.host.setPreset(this.preset);
    else this.host.setLayers(this.layers);
  }

  private updateWindow(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const ui = this.getUIContext();
      this.host?.setWindow(ui.px2vp(d.width), ui.px2vp(d.height), ui.vp2px(1));
    } catch (e) {
      // Metrics are only used for on-screen checks; keep the defaults.
    }
  }

  build() {
    XComponent({ type: XComponentType.SURFACE, controller: this.surface })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(this.interactive ? HitTestMode.Default : HitTestMode.None)
      .onAreaChange((_: Area, area: Area) => {
        const pos = area.globalPosition;
        this.host?.setLayout({
          x: Number(pos.x ?? 0), y: Number(pos.y ?? 0),
          width: Number(area.width), height: Number(area.height),
          dpr: this.getUIContext().vp2px(1),
        });
      })
      .onVisibleAreaChange([0.0, 0.01], (isVisible: boolean) => {
        if (!this.pauseWhenHidden) return;
        this.hidden = !isVisible;
        this.host?.setPaused(this.paused || this.hidden);
      })
      .onTouch((e: TouchEvent) => {
        if (!this.interactive || !this.host) return;
        const t = e.changedTouches.length > 0 ? e.changedTouches[0] : e.touches[0];
        if (!t) return;
        const kind = e.type === TouchType.Down ? 'down' : e.type === TouchType.Move ? 'move' : 'up';
        this.host.pointer(kind, t.windowX, t.windowY);
      })
  }
}
