import {
  nativeDispose, nativeGetStats, nativeInit, nativeResize, nativeSetEffect, nativeSetParam, nativeSetPaused,
  nativeSetPointer,
} from 'libshaderport_gles.so';
import { PassSource, ParamValue, getDefaultParams, getPassSources, initShaderPort } from '@quizzyjoy/shaderport';

let portInstalled = false;

export interface PortStats {
  fps: number;
  cpuMs: number;
}

/** The latest stats line from the shaderport renderer ("fps|cpuMs"). */
export function shaderPortStats(): PortStats {
  const parts = nativeGetStats().split('|');
  return { fps: Number(parts[0] ?? 0), cpuMs: Number(parts[1] ?? 0) };
}

/**
 * One shaderport effect, rendered by shaderport's own GLES 3.0 renderer (a process-wide
 * singleton, so one of these per page). Driven the same way as shaderport's demo page:
 * pass sources + default params from the HAR, pointer normalised to [0, 1] from the top.
 */
@Component
export struct ShaderPortView {
  @Prop @Watch('onEffectChange') effectId: string = '';
  onError: (message: string) => void = () => {};
  private controller: XComponentController = new XComponentController();
  private started: boolean = false;
  private viewWidth: number = 1;
  private viewHeight: number = 1;

  aboutToAppear(): void {
    if (!portInstalled) {
      portInstalled = true;
      initShaderPort(getContext(this).resourceManager);
    }
  }

  aboutToDisappear(): void {
    if (this.started) {
      nativeDispose();
      this.started = false;
    }
  }

  onEffectChange(): void {
    if (this.started) this.load();
  }

  private load(): void {
    if (!this.effectId) return;
    try {
      const sources: PassSource[] = getPassSources(this.effectId);
      const fragments: string[] = [];
      const blocks: string[] = [];
      const instances: string[] = [];
      sources.forEach((s: PassSource) => {
        fragments.push(s.fragment);
        blocks.push(s.block);
        instances.push(s.instance);
      });
      if (!nativeSetEffect(fragments, blocks, instances)) this.onError('shader compile failed');
      getDefaultParams(this.effectId).forEach((v: ParamValue) => nativeSetParam(v.name, v.values));
      nativeSetPaused(false);
    } catch (e) {
      this.onError(`${e}`);
    }
  }

  private pointer(x: number, y: number, active: number): void {
    nativeSetPointer(Math.max(0, Math.min(1, x / this.viewWidth)), Math.max(0, Math.min(1, y / this.viewHeight)), active);
  }

  build() {
    XComponent({ type: XComponentType.SURFACE, controller: this.controller })
      .width('100%')
      .height('100%')
      .onLoad(() => {
        const ui = this.getUIContext();
        const ok = nativeInit(this.controller.getXComponentSurfaceId(),
          Math.max(1, Math.round(ui.vp2px(this.viewWidth))), Math.max(1, Math.round(ui.vp2px(this.viewHeight))));
        if (!ok) {
          this.onError('EGL init failed');
          return;
        }
        this.started = true;
        this.load();
      })
      .onAreaChange((_: Area, area: Area) => {
        const w = Number(area.width), h = Number(area.height);
        if (w > 0 && h > 0) {
          this.viewWidth = w;
          this.viewHeight = h;
          const ui = this.getUIContext();
          nativeResize(Math.round(ui.vp2px(w)), Math.round(ui.vp2px(h)));
        }
      })
      .onTouch((e: TouchEvent) => {
        const t = e.changedTouches.length > 0 ? e.changedTouches[0] : e.touches[0];
        if (!t) return;
        this.pointer(t.x, t.y, e.type === TouchType.Up || e.type === TouchType.Cancel ? 0 : 1);
      })
  }
}
