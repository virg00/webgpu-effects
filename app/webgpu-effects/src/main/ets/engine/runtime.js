// Browser environment for the shaders engine inside the Ark JS runtime.
//
// The engine was written for the DOM; this module installs just enough of it on globalThis:
// navigator.gpu (webgpu.js), window events + metrics, requestAnimationFrame driven by the display
// vsync, a 2D canvas backed by ArkUI's OffscreenCanvas, fonts, images and a few small globals.
// Surface-backed canvases (one per ShaderView) are created with createSurfaceCanvas().
import displaySync from '@ohos.graphics.displaySync';
import media from '@ohos.multimedia.media';
import * as gpu from './webgpu';

const native = gpu.gpuNative;
const g = globalThis;

// ── events ──────────────────────────────────────────────────────────────────────────────────

class EventTargetShim {
  constructor() { this._l = new Map(); }
  addEventListener(type, fn, opts) {
    if (!fn) return;
    if (!this._l.has(type)) this._l.set(type, new Set());
    this._l.get(type).add(fn);
    const signal = opts && typeof opts === 'object' ? opts.signal : undefined;
    signal?.addEventListener?.('abort', () => this.removeEventListener(type, fn));
  }
  removeEventListener(type, fn) { this._l.get(type)?.delete(fn); }
  dispatchEvent(ev) {
    for (const fn of [...(this._l.get(ev.type) ?? [])]) {
      try { typeof fn === 'function' ? fn.call(this, ev) : fn.handleEvent(ev); } catch (e) { console.error('[shaders] event handler threw', String(e), e?.stack); }
    }
    return true;
  }
}

function makeEvent(type, props) {
  return Object.assign({ type, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, stopPropagation() {} }, props);
}

// ── time & frames ───────────────────────────────────────────────────────────────────────────

const t0 = Date.now();
const perf = { now: () => (native.now ? native.now() : Date.now() - t0), timeOrigin: t0, mark() {}, measure() {} };

let rafQueue = new Map();
let rafNext = 1;
let sync = null;
let inFrame = false;
const surfaceCanvases = new Set();
let presentScheduled = false;

let maxFps = 120;

/**
 * Upper bound for the render loop (default 120, i.e. follow the display). Also the rate requested
 * from the display: on LTPO screens a 60 request drops the whole window to 60 Hz.
 */
export function setMaxFrameRate(fps) {
  maxFps = Math.max(1, Math.min(120, Math.round(fps)));
  // The engine's on-screen cap (patched into the bundle, see scripts/patch-bundle.mjs); 1 ms of
  // jitter tolerance as upstream uses for 60 fps.
  g.__SHADERS_MIN_FRAME_INTERVAL = 1000 / maxFps - 1;
  sync?.setExpectedFrameRateRange({ expected: maxFps, min: 0, max: maxFps });
}

function ensureSync() {
  if (sync) return;
  sync = displaySync.create();
  sync.setExpectedFrameRateRange({ expected: maxFps, min: 0, max: maxFps });
  sync.on('frame', onFrame);
  sync.start();
}

let cpuMsEma = 0;

function onFrame(info) {
  // Hand rAF the vsync timestamp like a browser does (same monotonic clock as performance.now):
  // the engine's 60 fps gate skips frames closer than 15.67 ms, and callback-time jitter would trip it.
  const vsync = info && info.timestamp ? info.timestamp / 1e6 : 0;
  const ts = vsync > 0 && native.now ? vsync : perf.now();
  const started = perf.now();
  inFrame = true;
  const batch = rafQueue;
  rafQueue = new Map();
  for (const cb of batch.values()) {
    try { cb(ts); } catch (e) { console.error('[shaders] rAF callback threw', String(e), e?.stack); }
  }
  inFrame = false;
  presentAll();
  gpu.pumpEvents();
  // CPU cost of one frame: engine callbacks + encoding + submit + present (same scope as
  // shaderport's "cpuMs", which times its native draw + swap).
  const spent = perf.now() - started;
  cpuMsEma = cpuMsEma === 0 ? spent : cpuMsEma * 0.9 + spent * 0.1;
}

function presentAll() {
  presentScheduled = false;
  const now = perf.now();
  for (const c of surfaceCanvases) {
    if (c._context?._present()) c._frameTimes.push(now);
  }
}

function schedulePresent() {
  if (inFrame || presentScheduled) return;
  presentScheduled = true;
  setTimeout(presentAll, 0);
}

function requestAnimationFrame(cb) {
  ensureSync();
  const id = rafNext++;
  rafQueue.set(id, cb);
  return id;
}
function cancelAnimationFrame(id) { rafQueue.delete(id); }

/** Stops the vsync callback while nothing is mounted. */
export function suspendFrames() {
  if (sync && surfaceCanvases.size === 0) { sync.stop(); sync.off('frame'); sync = null; }
}

// ── window / document ───────────────────────────────────────────────────────────────────────

const win = new EventTargetShim();
win.innerWidth = 360;
win.innerHeight = 780;
win.devicePixelRatio = 3;
win.location = { href: 'app://shaders/', origin: 'app://shaders', hostname: 'localhost', protocol: 'app:', pathname: '/', search: '', hash: '' };
win.matchMedia = (q) => ({ matches: /coarse|reduce/.test(q) ? /coarse/.test(q) : false, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} });
win.getComputedStyle = () => ({ position: 'relative', getPropertyValue: () => '' });
win.scrollX = 0;
win.scrollY = 0;

/** Window metrics in vp (CSS px) and the vp→px ratio. */
export function setWindowMetrics(widthVp, heightVp, dpr) {
  const changed = win.innerWidth !== widthVp || win.innerHeight !== heightVp;
  win.innerWidth = widthVp;
  win.innerHeight = heightVp;
  win.devicePixelRatio = dpr;
  g.devicePixelRatio = dpr;
  if (changed) win.dispatchEvent(makeEvent('resize', {}));
}

/** Pointer input in window vp coordinates: kind is 'down' | 'move' | 'up'. */
export function dispatchPointer(kind, x, y) {
  const touch = { clientX: x, clientY: y, pageX: x, pageY: y, screenX: x, screenY: y, identifier: 0 };
  const touches = kind === 'up' ? [] : [touch];
  const touchType = kind === 'down' ? 'touchstart' : kind === 'move' ? 'touchmove' : 'touchend';
  win.dispatchEvent(makeEvent(touchType, { touches, targetTouches: touches, changedTouches: [touch] }));
  const mouseType = kind === 'down' ? 'mousedown' : kind === 'move' ? 'mousemove' : 'mouseup';
  win.dispatchEvent(makeEvent(mouseType, { clientX: x, clientY: y, pageX: x, pageY: y, button: 0, buttons: kind === 'up' ? 0 : 1 }));
}

class Style {
  constructor(owner) { this._owner = owner; }
  setProperty(k, v) { this[k] = v; }
  getPropertyValue(k) { return this[k] ?? ''; }
  removeProperty(k) { delete this[k]; }
}

class ElementShim extends EventTargetShim {
  constructor(tag) {
    super();
    this.tagName = tag.toUpperCase();
    this.nodeName = this.tagName;
    this.style = new Style(this);
    this.children = [];
    this.parentElement = null;
    this.isConnected = false;
    this.dataset = {};
  }
  appendChild(c) { this.children.push(c); c.parentElement = this; return c; }
  removeChild(c) { this.children = this.children.filter((x) => x !== c); c.parentElement = null; return c; }
  remove() { this.parentElement?.removeChild(this); }
  setAttribute(k, v) { this[k] = v; }
  getAttribute(k) { return this[k] ?? null; }
  removeAttribute(k) { delete this[k]; }
  getBoundingClientRect() { return rect(0, 0, 0, 0); }
  contains(other) { return other === this; }
  querySelector() { return null; }
  querySelectorAll() { return []; }
  get ownerDocument() { return document; }
}

function rect(left, top, width, height) {
  return { left, top, width, height, x: left, y: top, right: left + width, bottom: top + height, toJSON() { return this; } };
}

// ── 2D canvas on ArkUI OffscreenCanvas ──────────────────────────────────────────────────────

const PX = 1; // LengthMetricsUnit.PX

const CTX_DEFAULTS = {
  font: '10px sans-serif', fillStyle: '#000000', strokeStyle: '#000000', textAlign: 'start',
  textBaseline: 'alphabetic', globalAlpha: 1, lineWidth: 1, globalCompositeOperation: 'source-over',
  letterSpacing: '0px', fontKerning: 'auto', direction: 'inherit', filter: 'none',
  imageSmoothingEnabled: true, imageSmoothingQuality: 'low',
};

class Canvas2D extends ElementShim {
  constructor() {
    super('canvas');
    this._w = 300;
    this._h = 150;
    this._oc = null;
    this._ctx = null;
    this._proxy = null;
    this._state = {};
  }
  get width() { return this._w; }
  set width(v) { this._w = Math.max(0, v | 0); this._reset(); }
  get height() { return this._h; }
  set height(v) { this._h = Math.max(0, v | 0); this._reset(); }
  _reset() { this._oc = null; this._ctx = null; this._state = {}; }
  _real() {
    if (!this._ctx) {
      const w = Math.max(1, this._w), h = Math.max(1, this._h);
      this._oc = new OffscreenCanvas(w, h, PX);
      this._ctx = this._oc.getContext('2d');
    }
    return this._ctx;
  }
  getContext(type) {
    if (type !== '2d') return null;
    if (!this._proxy) {
      const self = this;
      // The engine keeps the context across width/height changes, which recreate the backing
      // OffscreenCanvas, so hand out a stable proxy that forwards to whichever is current.
      this._proxy = new Proxy({}, {
        get(_, k) {
          if (k === 'canvas') return self;
          if (k === 'getImageData') return (x, y, w, h) => self._imageData(x, y, w, h);
          if (k === 'drawImage') return (img, ...rest) => self._real().drawImage(unwrapImage(img), ...rest);
          if (k === 'createPattern') return (img, rep) => self._real().createPattern(unwrapImage(img), rep);
          const ctx = self._real();
          const v = ctx[k];
          if (typeof v === 'function') return v.bind(ctx);
          // ArkUI does not read back every state property (e.g. `font`); answer with what was set.
          return v === undefined || v === null ? (self._state[k] ?? CTX_DEFAULTS[k]) : v;
        },
        set(_, k, v) {
          self._state[k] = v;
          try { self._real()[k] = v; } catch (_) { /* unsupported property */ }
          return true;
        },
        has(_, k) { return k in self._real(); },
      });
    }
    return this._proxy;
  }
  _imageData(x, y, w, h) {
    const id = this._real().getImageData(x, y, w, h);
    return { width: id.width, height: id.height, data: id.data, colorSpace: 'srgb' };
  }
  _rgba8() {
    if (this._w === 0 || this._h === 0) return null;
    const id = this._real().getImageData(0, 0, this._w, this._h);
    return { data: id.data, width: id.width, height: id.height };
  }
  _pixelMap() {
    return this._real().getPixelMap(0, 0, this._w, this._h);
  }
  transferToImageBitmap() { return this._oc ? this._oc.transferToImageBitmap() : null; }
  toDataURL() { return this._oc ? this._real().toDataURL() : ''; }
  toBlob(cb) { cb(null); }
}

function unwrapImage(img) {
  if (img instanceof Canvas2D) return img._pixelMap();
  if (img && img._pixelMap) return img._pixelMap();
  return img;
}

// ── images: rawfile / resource / data: / http(s) sources decoded to RGBA8 ───────────────────

let imageLoader = null;
/** The ShaderView module installs the platform image decoder (needs a UIAbility context). */
export function setImageLoader(fn) { imageLoader = fn; }

class Bitmap {
  constructor(data, width, height, pixelMap) {
    this._data = data;
    this.width = width;
    this.height = height;
    this._pm = pixelMap;
  }
  _rgba8() { return { data: this._data, width: this.width, height: this.height }; }
  _pixelMap() { return this._pm; }
  close() { this._data = null; this._pm?.release?.(); this._pm = null; }
}

class ImageShim extends ElementShim {
  constructor() {
    super('img');
    this.onload = null;
    this.onerror = null;
    this.crossOrigin = null;
    this.decoding = 'async';
    this.complete = false;
    this.naturalWidth = 0;
    this.naturalHeight = 0;
    this._bmp = null;
    this._src = '';
  }
  get width() { return this.naturalWidth; }
  get height() { return this.naturalHeight; }
  get src() { return this._src; }
  set src(v) {
    this._src = v;
    this.complete = false;
    loadBitmap(v).then((bmp) => {
      this._bmp = bmp;
      this.naturalWidth = bmp.width;
      this.naturalHeight = bmp.height;
      this.complete = true;
      this.onload?.(makeEvent('load', {}));
      this.dispatchEvent(makeEvent('load', {}));
    }, (e) => {
      this.complete = true;
      this.onerror?.(makeEvent('error', { error: e }));
      this.dispatchEvent(makeEvent('error', { error: e }));
    });
  }
  decode() {
    return new Promise((resolve, reject) => {
      if (this.complete && this._bmp) { resolve(); return; }
      this.addEventListener('load', () => resolve());
      this.addEventListener('error', (e) => reject(e.error ?? new Error('decode failed')));
    });
  }
  _rgba8() { return this._bmp?._rgba8() ?? null; }
  _pixelMap() { return this._bmp?._pixelMap() ?? null; }
}

async function loadBitmap(src) {
  if (!imageLoader) throw new Error('no image loader installed');
  const r = await imageLoader(src);
  return new Bitmap(r.data, r.width, r.height, r.pixelMap);
}

class BlobShim {
  constructor(parts, opts) { this._parts = parts ?? []; this.type = opts?.type ?? ''; this._url = opts?._url; }
  async arrayBuffer() { return this._bytes ?? new ArrayBuffer(0); }
}

async function createImageBitmap(source) {
  if (source instanceof BlobShim) return loadBitmap(source._url);
  if (source instanceof ImageShim) { await source.decode(); return source._bmp; }
  if (source instanceof Canvas2D) { const r = source._rgba8(); return new Bitmap(r.data, r.width, r.height, source._pixelMap()); }
  if (source instanceof Bitmap) return source;
  throw new TypeError('createImageBitmap: unsupported source');
}

// fetch() only serves what the engine fetches itself: media to decode, and (blocked) telemetry.
async function fetchShim(url, init) {
  const u = String(url?.url ?? url);
  if (/telemetry|\/api\//.test(u)) return { ok: false, status: 204, json: async () => ({}), text: async () => '' };
  return {
    ok: true, status: 200, url: u, headers: { get: () => null },
    blob: async () => new BlobShim([], { _url: u }),
    arrayBuffer: async () => { throw new Error('fetch: arrayBuffer unsupported for ' + u); },
    json: async () => { throw new Error('fetch: json unsupported for ' + u); },
    text: async () => '',
  };
}


// ── video: AVPlayer (URL sources) and camera (getUserMedia) into a native consumer surface ─────

let mediaResolver = null;
let cameraProvider = null;
/** host.ts installs these: URL → AVPlayer source, and surfaceId → running camera preview. */
export function setMediaResolver(fn) { mediaResolver = fn; }
export function setCameraProvider(fn) { cameraProvider = fn; }

class MediaStreamShim {
  constructor(frames, stop) { this._frames = frames; this._stop = stop; this.active = true; }
  getTracks() { return [{ kind: 'video', stop: () => { if (this.active) { this.active = false; this._stop?.(); } } }]; }
  getVideoTracks() { return this.getTracks(); }
}

class VideoShim extends ElementShim {
  constructor() {
    super('video');
    this.readyState = 0;
    this.videoWidth = 0;
    this.videoHeight = 0;
    this.paused = true;
    this.muted = true;
    this.playsInline = true;
    this.crossOrigin = null;
    this.onloadedmetadata = null;
    this.onerror = null;
    this._loop = false;
    this._src = '';
    this._player = null;
    this._frames = null;
    this._stream = null;
    this._prepared = false;
    this._wantPlay = false;
    this._gen = 0;
  }
  get loop() { return this._loop; }
  set loop(v) { this._loop = !!v; if (this._player && this._prepared) this._player.loop = this._loop; }
  get currentTime() { return (this._player?.currentTime ?? 0) / 1000; }
  set currentTime(t) { this._player?.seek(Math.round(t * 1000)); }
  get duration() { return (this._player?.duration ?? 0) / 1000; }
  get src() { return this._src; }
  set src(v) {
    this._src = v || '';
    this._teardown();
    if (this._src) void this._open(this._src);
  }
  get srcObject() { return this._stream; }
  set srcObject(stream) {
    this._teardown();
    this._stream = stream;
    if (!stream) return;
    this._frames = stream._frames;
    // The camera already runs; metadata arrives with the first frame.
    const gen = this._gen;
    const poll = () => {
      if (gen !== this._gen || !this._stream) return;
      if (this._frames.width === 0) { this._probeFrame(); }
      if (this._frames.width > 0) this._loaded(this._frames.width, this._frames.height);
      else setTimeout(poll, 30);
    };
    poll();
  }
  _probeFrame() {
    // Upload needs a device; size alone comes from the acquire, so peek through the default device.
    const dev = gpu.anyDevice();
    if (dev) this._frames.texture(dev);
  }
  _loaded(w, h) {
    this.videoWidth = w;
    this.videoHeight = h;
    this.readyState = 4;
    this.onloadedmetadata?.(makeEvent('loadedmetadata', {}));
    this.dispatchEvent(makeEvent('loadedmetadata', {}));
    this.dispatchEvent(makeEvent('loadeddata', {}));
  }
  _fail(e) {
    console.error('[video]', String(e));
    this.onerror?.(makeEvent('error', { error: e }));
    this.dispatchEvent(makeEvent('error', { error: e }));
  }
  async _open(url) {
    const gen = ++this._gen;
    try {
      this._frames = new gpu.VideoFrameSource();
      const player = await media.createAVPlayer();
      if (gen !== this._gen) { player.release(); return; }
      this._player = player;
      player.on('error', (err) => this._fail(new Error(`AVPlayer: ${err?.code} ${err?.message}`)));
      player.on('stateChange', async (state) => {
        if (gen !== this._gen) return;
        if (state === 'initialized') {
          player.surfaceId = this._frames.surfaceId;
          await player.prepare();
        } else if (state === 'prepared') {
          this._prepared = true;
          player.loop = this._loop;
          player.setVolume?.(0);
          this._loaded(player.width, player.height);
          if (this._wantPlay) player.play();
        } else if (state === 'completed' && this._loop) {
          player.play();
        }
      });
      const source = mediaResolver ? await mediaResolver(url) : { url };
      if (gen !== this._gen) return;
      if (source.fdSrc) player.fdSrc = source.fdSrc;
      else player.url = source.url;
    } catch (e) {
      this._fail(e);
    }
  }
  play() {
    this._wantPlay = true;
    this.paused = false;
    if (this._player && this._prepared) this._player.play();
    return Promise.resolve();
  }
  pause() {
    this._wantPlay = false;
    this.paused = true;
    if (this._player && this._prepared) this._player.pause();
  }
  load() {}
  _teardown() {
    this._gen++;
    this._prepared = false;
    if (this._player) { try { this._player.release(); } catch (_) { /* already released */ } }
    this._player = null;
    if (!this._stream) this._frames = null;
    this._stream = null;
    this.readyState = 0;
    this.videoWidth = this.videoHeight = 0;
  }
  _gpuTexture(device) { return this._frames?.texture(device) ?? null; }
}

const mediaDevices = {
  async getUserMedia(constraints) {
    if (!cameraProvider) throw new Error('NotAllowedError: camera unavailable');
    const frames = new gpu.VideoFrameSource();
    const facing = constraints?.video?.facingMode;
    const stop = await cameraProvider(frames.surfaceId, typeof facing === 'string' ? facing : facing?.ideal ?? 'user');
    return new MediaStreamShim(frames, stop);
  },
  async enumerateDevices() { return [{ kind: 'videoinput', deviceId: 'camera', label: 'Camera' }]; },
  addEventListener() {},
  removeEventListener() {},
};

// ── fonts ───────────────────────────────────────────────────────────────────────────────────

const fonts = new EventTargetShim();
fonts.status = 'loaded';
fonts.ready = Promise.resolve(fonts);
fonts.check = () => true;
fonts.load = async () => [];
fonts.add = () => {};
fonts.forEach = () => {};

// ── surface canvases (XComponent) ───────────────────────────────────────────────────────────

class SurfaceCanvas extends ElementShim {
  constructor(surface) {
    super('canvas');
    this._surface = surface;
    this._w = 1;
    this._h = 1;
    this._rect = rect(0, 0, 1, 1);
    this._context = null;
    this._frameTimes = [];
    this.isConnected = true;
    this.parentElement = new ElementShim('div');
    this.parentElement.getBoundingClientRect = () => this._rect;
    surfaceCanvases.add(this);
  }
  get width() { return this._w; }
  set width(v) { const n = Math.max(1, v | 0); if (n !== this._w) { this._w = n; this._context?._invalidateSize(); } }
  get height() { return this._h; }
  set height(v) { const n = Math.max(1, v | 0); if (n !== this._h) { this._h = n; this._context?._invalidateSize(); } }
  get clientWidth() { return this._rect.width; }
  get clientHeight() { return this._rect.height; }
  getBoundingClientRect() { return this._rect; }
  getContext(type) {
    if (type !== 'webgpu') return null;
    if (!this._context) this._context = new gpu.GPUCanvasContext(this);
    return this._context;
  }
  _onAcquire() { schedulePresent(); }
  /** Presented frames per second over the last second, and the CPU time per frame (ms). */
  stats() {
    const now = perf.now();
    this._frameTimes = this._frameTimes.filter((t) => now - t <= 1000);
    return { fps: this._frameTimes.length, cpuMs: cpuMsEma };
  }
  /** Layout from ArkUI, in window vp. */
  setLayout(left, top, width, height) { this._rect = rect(left, top, width, height); }
  dispose() {
    surfaceCanvases.delete(this);
    this._context?.unconfigure();
    this._context = null;
    if (this._surface) native.surfaceDestroy(this._surface);
    this._surface = null;
    suspendFrames();
  }
}

/** Wraps an XComponent surface id in a canvas the engine can render into. */
export function createSurfaceCanvas(surfaceId) {
  const surface = native.createSurface(String(surfaceId));
  if (!surface) return null;
  ensureAdapterFormat(surface);
  return new SurfaceCanvas(surface);
}

let formatProbed = false;
function ensureAdapterFormat(surface) {
  if (formatProbed) return;
  formatProbed = true;
  const adapter = native.requestAdapter({ powerPreference: 'high-performance' });
  if (!adapter) return;
  const caps = native.surfaceCapabilities(surface, adapter);
  const formats = caps.formats ?? [];
  const pick = ['rgba8unorm', 'bgra8unorm'].find((f) => formats.includes(f)) ?? formats.find((f) => !f.endsWith('-srgb'));
  if (pick) gpu.setPreferredCanvasFormat(pick);
}

// ── misc globals ────────────────────────────────────────────────────────────────────────────

class ObserverShim {
  constructor(cb) { this._cb = cb; }
  observe() {}
  unobserve() {}
  disconnect() {}
  takeRecords() { return []; }
}

class AbortSignalShim extends EventTargetShim {
  constructor() { super(); this.aborted = false; this.reason = undefined; this.onabort = null; }
  throwIfAborted() { if (this.aborted) throw this.reason; }
}
class AbortControllerShim {
  constructor() { this.signal = new AbortSignalShim(); }
  abort(reason) {
    if (this.signal.aborted) return;
    this.signal.aborted = true;
    this.signal.reason = reason ?? new Error('AbortError');
    this.signal.onabort?.(makeEvent('abort', {}));
    this.signal.dispatchEvent(makeEvent('abort', {}));
  }
}

class TextEncoderShim {
  get encoding() { return 'utf-8'; }
  encode(s = '') {
    const out = [];
    for (const ch of String(s)) {
      let c = ch.codePointAt(0);
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xC0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return new Uint8Array(out);
  }
}
class TextDecoderShim {
  decode(buf) {
    const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf?.buffer ?? buf ?? []);
    let s = '';
    for (let i = 0; i < b.length;) {
      const c = b[i++];
      let cp;
      if (c < 0x80) cp = c;
      else if (c < 0xE0) cp = ((c & 31) << 6) | (b[i++] & 63);
      else if (c < 0xF0) cp = ((c & 15) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63);
      else cp = ((c & 7) << 18) | ((b[i++] & 63) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63);
      s += String.fromCodePoint(cp);
    }
    return s;
  }
}

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function atobShim(input) {
  const str = String(input).replace(/[\s=]+/g, '');
  let out = '';
  for (let i = 0, bits = 0, acc = 0; i < str.length; i++) {
    const v = B64.indexOf(str[i]);
    if (v < 0) throw new Error('InvalidCharacterError');
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) { bits -= 8; out += String.fromCharCode((acc >> bits) & 0xff); }
  }
  return out;
}
function btoaShim(input) {
  const str = String(input);
  let out = '';
  for (let i = 0; i < str.length; i += 3) {
    const a = str.charCodeAt(i), b = str.charCodeAt(i + 1), c = str.charCodeAt(i + 2);
    const n = (a << 16) | ((b || 0) << 8) | (c || 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (i + 1 < str.length ? B64[(n >> 6) & 63] : '=') + (i + 2 < str.length ? B64[n & 63] : '=');
  }
  return out;
}

const document = new EventTargetShim();
document.visibilityState = 'visible';
document.hidden = false;
document.readyState = 'complete';
document.fonts = fonts;
document.head = new ElementShim('head');
document.body = new ElementShim('body');
document.documentElement = new ElementShim('html');
document.createElement = (tag) => {
  const t = String(tag).toLowerCase();
  if (t === 'canvas') return new Canvas2D();
  if (t === 'img') return new ImageShim();
  if (t === 'video') return new VideoShim();
  return new ElementShim(t);
};
document.getElementById = () => null;
document.querySelector = () => null;
document.querySelectorAll = () => [];

function define(name, value) {
  try {
    if (g[name] === undefined) g[name] = value;
  } catch (_) {
    Object.defineProperty(g, name, { value, configurable: true, writable: true });
  }
}

let installed = false;

/** Installs the browser globals. Idempotent. */
export function installRuntime() {
  if (installed) return;
  installed = true;
  setMaxFrameRate(maxFps);
  // Engine diagnostics print Error objects; Ark's console drops their stacks, so add them.
  const origError = console.error.bind(console);
  console.error = (...args) => origError(...args.map((a) => (a instanceof Error ? `${a}\n${a.stack ?? ''}` : a)));
  define('window', win);
  define('self', g);
  define('document', document);
  define('navigator', {});
  g.navigator.gpu = new gpu.GPU();
  g.navigator.userAgent = g.navigator.userAgent ?? 'Mozilla/5.0 (Phone; OpenHarmony) Shaders/1.0';
  g.navigator.doNotTrack = '1';
  g.navigator.hardwareConcurrency = g.navigator.hardwareConcurrency ?? 8;
  define('performance', perf);
  if (typeof g.performance.now !== 'function') g.performance.now = perf.now;
  define('requestAnimationFrame', requestAnimationFrame);
  define('cancelAnimationFrame', cancelAnimationFrame);
  define('queueMicrotask', (fn) => Promise.resolve().then(fn));
  define('ResizeObserver', ObserverShim);
  define('IntersectionObserver', ObserverShim);
  define('MutationObserver', ObserverShim);
  define('AbortController', AbortControllerShim);
  define('TextEncoder', TextEncoderShim);
  define('TextDecoder', TextDecoderShim);
  define('Image', ImageShim);
  define('Blob', BlobShim);
  define('createImageBitmap', createImageBitmap);
  define('fetch', fetchShim);
  define('atob', atobShim);
  define('btoa', btoaShim);
  define('getComputedStyle', win.getComputedStyle);
  define('matchMedia', win.matchMedia);
  define('devicePixelRatio', 3);
  define('HTMLCanvasElement', Canvas2D);
  define('HTMLImageElement', ImageShim);
  define('HTMLVideoElement', VideoShim);
  g.navigator.mediaDevices = mediaDevices;
  define('ImageBitmap', Bitmap);
  for (const k of ['GPUBufferUsage', 'GPUTextureUsage', 'GPUShaderStage', 'GPUMapMode', 'GPUColorWrite', 'GPUError',
    'GPUValidationError', 'GPUOutOfMemoryError', 'GPUInternalError', 'GPUPipelineError', 'GPUDevice', 'GPUAdapter',
    'GPUBuffer', 'GPUTexture', 'GPUCanvasContext', 'GPUCommandEncoder', 'GPUQuerySet', 'GPUSampler', 'GPUTextureView']) {
    define(k, gpu[k]);
  }
  // Window-level aliases the engine reads through `window.` as well as bare globals.
  for (const k of ['requestAnimationFrame', 'cancelAnimationFrame', 'performance', 'navigator', 'document', 'fetch']) win[k] = g[k];
  win.setTimeout = setTimeout;
  win.clearTimeout = clearTimeout;
}
