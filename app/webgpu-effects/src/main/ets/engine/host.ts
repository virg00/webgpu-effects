// One live shader per ShaderView: owns the surface canvas and the engine instance, and turns
// layer-tree changes into in-place prop updates or rebuilds.
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import {
  installRuntime, createSurfaceCanvas, setWindowMetrics, dispatchPointer, setImageLoader, setMediaResolver,
  setCameraProvider, setMaxFrameRate as runtimeSetMaxFrameRate,
} from './runtime';
import { createShader, getWebGPUSupport, setShadersDebug } from './bundle';
import type { PresetConfig, ShaderNode, ShaderOptions } from '../components/types';

installRuntime();

const DOMAIN = 0x5348;
const TAG = 'webgpu-fx';

export interface DecodedImage {
  data: ArrayBuffer;
  width: number;
  height: number;
  pixelMap: image.PixelMap;
}

let appContext: common.Context | null = null;

async function readSource(src: string): Promise<ArrayBuffer> {
  if (src.startsWith('data:')) {
    const comma = src.indexOf(',');
    const b64 = src.substring(comma + 1);
    return new util.Base64Helper().decodeSync(b64).buffer as ArrayBuffer;
  }
  if (src.startsWith('rawfile://') || (!src.includes('://') && !src.startsWith('/'))) {
    const path = src.replace('rawfile://', '');
    const bytes = await appContext!.resourceManager.getRawFileContent(path);
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  }
  if (src.startsWith('http://') || src.startsWith('https://')) {
    const req = http.createHttp();
    try {
      const res = await req.request(src, { expectDataType: http.HttpDataType.ARRAY_BUFFER, readTimeout: 30000, connectTimeout: 15000 });
      if (res.responseCode < 200 || res.responseCode >= 300) throw new Error(`HTTP ${res.responseCode} for ${src}`);
      return res.result as ArrayBuffer;
    } finally {
      req.destroy();
    }
  }
  // file:// or absolute sandbox path
  const path = src.replace('file://', '');
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const buf = new ArrayBuffer(fs.statSync(path).size);
    fs.readSync(file.fd, buf);
    return buf;
  } finally {
    fs.closeSync(file);
  }
}

async function decodeImage(src: string): Promise<DecodedImage> {
  const bytes = await readSource(src);
  const source = image.createImageSource(bytes);
  try {
    const pm = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888, editable: false });
    const info = await pm.getImageInfo();
    const w = info.size.width, h = info.size.height;
    const data = new ArrayBuffer(w * h * 4);
    await pm.readPixelsToBuffer(data);
    // PixelMaps decode premultiplied; the engine expects straight alpha like the browser's decoder.
    if (info.alphaType === image.AlphaType.PREMUL) unpremultiply(new Uint8Array(data));
    return { data, width: w, height: h, pixelMap: pm };
  } finally {
    source.release();
  }
}

function unpremultiply(px: Uint8Array): void {
  for (let i = 0; i < px.length; i += 4) {
    const a = px[i + 3];
    if (a === 0 || a === 255) continue;
    px[i] = Math.min(255, Math.round(px[i] * 255 / a));
    px[i + 1] = Math.min(255, Math.round(px[i + 1] * 255 / a));
    px[i + 2] = Math.min(255, Math.round(px[i + 2] * 255 / a));
  }
}

interface MediaSource {
  url?: string;
  fdSrc?: media.AVFileDescriptor;
}

/** Where AVPlayer should read a VideoTexture `url` from. */
async function resolveMedia(src: string): Promise<MediaSource> {
  if (src.startsWith('http://') || src.startsWith('https://')) return { url: src };
  if (src.startsWith('rawfile://') || (!src.includes('://') && !src.startsWith('/'))) {
    const fd = await appContext!.resourceManager.getRawFd(src.replace('rawfile://', ''));
    return { fdSrc: { fd: fd.fd, offset: fd.offset, length: fd.length } };
  }
  const file = fs.openSync(src.replace('file://', ''), fs.OpenMode.READ_ONLY);
  return { url: `fd://${file.fd}` };
}

/** Starts the camera previewing into `surfaceId`; resolves with a stop function. */
async function startCamera(surfaceId: string, facing: string): Promise<() => void> {
  const ctx = appContext!;
  const perm: Permissions = 'ohos.permission.CAMERA';
  const atManager = abilityAccessCtrl.createAtManager();
  const grant = await atManager.requestPermissionsFromUser(ctx, [perm]);
  if (grant.authResults[0] !== 0) throw new Error('NotAllowedError: camera permission denied');
  const manager = camera.getCameraManager(ctx);
  const cameras = manager.getSupportedCameras();
  const wanted = facing === 'environment' ? camera.CameraPosition.CAMERA_POSITION_BACK : camera.CameraPosition.CAMERA_POSITION_FRONT;
  const device = cameras.find((c: camera.CameraDevice) => c.cameraPosition === wanted) ?? cameras[0];
  if (!device) throw new Error('NotFoundError: no camera');
  const caps = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
  // Prefer a ~720p YUV preview: plenty for effects, cheap to upload every frame.
  const profiles = caps.previewProfiles.filter((p: camera.Profile) => p.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP);
  const pool = profiles.length ? profiles : caps.previewProfiles;
  const profile = pool.reduce((best: camera.Profile, p: camera.Profile) =>
    Math.abs(p.size.width * p.size.height - 1280 * 720) < Math.abs(best.size.width * best.size.height - 1280 * 720) ? p : best);
  const input = manager.createCameraInput(device);
  await input.open();
  const preview = manager.createPreviewOutput(profile, surfaceId);
  const session = manager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
  session.beginConfig();
  session.addInput(input);
  session.addOutput(preview);
  await session.commitConfig();
  await session.start();
  return () => {
    void session.stop().then(() => session.release()).then(() => input.close()).catch(() => {});
  };
}

/** Must be called once with a UIAbility/application context before images from rawfile can load. */
export function initShaders(context: common.Context): void {
  appContext = context;
  setImageLoader(decodeImage);
  setMediaResolver(resolveMedia);
  setCameraProvider(startCamera);
}

/** Caps every ShaderView's frame rate (default 120 = follow the display; 60 halves the GPU/CPU cost). */
export function setMaxFrameRate(fps: number): void {
  runtimeSetMaxFrameRate(fps);
}

export function setDebug(on: boolean): void {
  setShadersDebug(on);
}

export async function isSupported(): Promise<boolean> {
  const s = await getWebGPUSupport();
  return !!s.supported;
}

// ── layer tree → preset ─────────────────────────────────────────────────────────────────────

interface ComponentConfig {
  type: string;
  id: string;
  props: Record<string, Object>;
  children?: ComponentConfig[];
}

function toConfig(nodes: ShaderNode[], prefix: string): ComponentConfig[] {
  return nodes.map((n, i) => {
    const id = n.id ?? `${prefix}${i}-${n.type}`;
    const c: ComponentConfig = { type: n.type, id, props: { ...((n.props ?? {}) as Record<string, Object>) } };
    if (n.children && n.children.length) c.children = toConfig(n.children, `${id}/`);
    return c;
  });
}

function cloneConfig(cs: ComponentConfig[]): ComponentConfig[] {
  return cs.map((c) => {
    const out: ComponentConfig = { type: c.type, id: c.id, props: { ...c.props } };
    if (c.children) out.children = cloneConfig(c.children);
    return out;
  });
}

function structureKey(cs: ComponentConfig[]): string {
  // Anything that changes the composition graph forces a rebuild; plain prop values do not.
  return cs.map((c) => `${c.id}:${c.type}[${structureKey(c.children ?? [])}]`).join(',');
}

function flatten(cs: ComponentConfig[], out: Map<string, ComponentConfig>): Map<string, ComponentConfig> {
  for (const c of cs) {
    out.set(c.id, c);
    if (c.children) flatten(c.children, out);
  }
  return out;
}

function sameValue(a: Object | undefined, b: Object | undefined): boolean {
  if (a === b) return true;
  return JSON.stringify(a) === JSON.stringify(b);
}

// ── host ────────────────────────────────────────────────────────────────────────────────────

interface EngineInstance {
  update(id: string, props: Record<string, Object>): void;
  resize(width?: number, height?: number): void;
  pause(): void;
  resume(): void;
  destroy(): void;
  getFailureReason(): string | null;
}

export interface FrameStats {
  /** Frames presented during the last second. */
  fps: number;
  /** CPU time per frame in ms (engine + encoding + submit), smoothed. */
  cpuMs: number;
}

interface Layout { x: number; y: number; width: number; height: number; dpr: number; }

export class ShaderHost {
  private canvas: ReturnType<typeof createSurfaceCanvas> = null;
  private instance: EngineInstance | null = null;
  private config: ComponentConfig[] = [];
  /** The config the running instance was built from or last synced to. */
  private applied: ComponentConfig[] = [];
  private key = '';
  private layout: Layout = { x: 0, y: 0, width: 1, height: 1, dpr: 1 };
  private paused = false;
  private disposed = false;
  private generation = 0;

  constructor(private options: ShaderOptions) {}

  attach(surfaceId: string): void {
    this.canvas = createSurfaceCanvas(surfaceId);
    if (!this.canvas) {
      hilog.error(DOMAIN, TAG, 'could not create a GPU surface for %{public}s', surfaceId);
      this.options.onError?.('no-surface');
      return;
    }
    this.applyLayout();
    void this.rebuild();
  }

  detach(): void {
    this.destroyInstance();
    this.canvas?.dispose();
    this.canvas = null;
  }

  dispose(): void {
    this.disposed = true;
    this.detach();
  }

  setLayout(l: Layout): void {
    this.layout = l;
    this.applyLayout();
  }

  setWindow(widthVp: number, heightVp: number, dpr: number): void {
    setWindowMetrics(widthVp, heightVp, dpr);
  }

  pointer(kind: 'down' | 'move' | 'up', windowX: number, windowY: number): void {
    dispatchPointer(kind, windowX, windowY);
  }

  setLayers(nodes: ShaderNode[]): void {
    this.setConfig(toConfig(nodes, ''));
  }

  setPreset(preset: PresetConfig): void {
    this.setConfig(toConfig(preset.components as ShaderNode[], ''));
  }

  update(id: string, props: Record<string, Object>): void {
    const c = flatten(this.config, new Map()).get(id);
    if (c) Object.assign(c.props, props);
    if (!this.instance) return;
    const a = flatten(this.applied, new Map()).get(id);
    if (a) Object.assign(a.props, props);
    this.instance.update(id, props);
  }

  stats(): FrameStats {
    return this.canvas ? this.canvas.stats() as FrameStats : { fps: 0, cpuMs: 0 };
  }

  setPaused(paused: boolean): void {
    this.paused = paused;
    if (!this.instance) return;
    paused ? this.instance.pause() : this.instance.resume();
  }

  private setConfig(next: ComponentConfig[]): void {
    this.config = next;
    if (structureKey(next) !== this.key) {
      void this.rebuild();
    } else if (this.instance) {
      this.syncProps();
    }
    // Same graph while a build is in flight: the build syncs when it finishes.
  }

  /** Pushes the props that differ between what the instance runs and the current config. */
  private syncProps(): void {
    if (!this.instance) return;
    const before = flatten(this.applied, new Map());
    for (const [id, c] of flatten(this.config, new Map())) {
      const old = before.get(id);
      const changed: Record<string, Object> = {};
      let any = false;
      const keys = new Set([...Object.keys(c.props), ...Object.keys(old?.props ?? {})]);
      for (const k of keys) {
        if (!sameValue(c.props[k], old?.props[k])) { changed[k] = c.props[k]; any = true; }
      }
      if (any) this.instance.update(id, changed);
    }
    this.applied = cloneConfig(this.config);
  }

  private applyLayout(): void {
    const c = this.canvas;
    if (!c) return;
    const l = this.layout;
    c.setLayout(l.x, l.y, l.width, l.height);
    c.style.width = `${l.width}px`;
    c.style.height = `${l.height}px`;
    this.instance?.resize();
  }

  private destroyInstance(): void {
    this.generation++;
    try { this.instance?.destroy(); } catch (e) { hilog.warn(DOMAIN, TAG, 'destroy failed %{public}s', String(e)); }
    this.instance = null;
  }

  private async rebuild(): Promise<void> {
    this.key = structureKey(this.config);
    if (!this.canvas || this.disposed) return;
    this.destroyInstance();
    const gen = this.generation;
    const built = cloneConfig(this.config);
    const preset = { components: cloneConfig(built) };
    try {
      const inst = await createShader(this.canvas, preset, {
        disableTelemetry: true,
        observeElement: false,
        colorSpace: this.options.colorSpace,
        toneMapping: this.options.toneMapping,
        onReady: () => this.options.onReady?.(),
        onError: (reason: string) => {
          hilog.warn(DOMAIN, TAG, 'shader error: %{public}s', reason);
          this.options.onError?.(reason);
        },
      }) as EngineInstance;
      if (gen !== this.generation || !this.canvas) { inst.destroy(); return; }
      this.instance = inst;
      this.applied = built;
      inst.resize();
      if (this.paused) inst.pause();
      this.syncProps(); // props that changed while building
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'createShader failed: %{public}s %{public}s', String(e), (e as Error)?.stack ?? '');
      this.options.onError?.('init-failed');
    }
  }
}
