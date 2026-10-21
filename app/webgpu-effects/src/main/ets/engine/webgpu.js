// WebGPU object model for the Ark JS runtime.
//
// Mirrors the browser API (navigator.gpu, GPUDevice, GPUBuffer, ...) closely enough for the
// shaders engine and TypeGPU, delegating every call to libwebgpu_effects.so (wgpu-native on Vulkan).
// Native handles live in `_n`; descriptor objects are passed through unchanged and read natively.
import native from 'libwebgpu_effects.so';

const RENDER = 0, BUNDLE = 1, COMPUTE = 2;

export const GPUBufferUsage = Object.freeze({
  MAP_READ: 0x1, MAP_WRITE: 0x2, COPY_SRC: 0x4, COPY_DST: 0x8, INDEX: 0x10, VERTEX: 0x20,
  UNIFORM: 0x40, STORAGE: 0x80, INDIRECT: 0x100, QUERY_RESOLVE: 0x200,
});
export const GPUTextureUsage = Object.freeze({
  COPY_SRC: 0x1, COPY_DST: 0x2, TEXTURE_BINDING: 0x4, STORAGE_BINDING: 0x8, RENDER_ATTACHMENT: 0x10,
});
export const GPUShaderStage = Object.freeze({ VERTEX: 0x1, FRAGMENT: 0x2, COMPUTE: 0x4 });
export const GPUMapMode = Object.freeze({ READ: 0x1, WRITE: 0x2 });
export const GPUColorWrite = Object.freeze({ RED: 0x1, GREEN: 0x2, BLUE: 0x4, ALPHA: 0x8, ALL: 0xF });

export class GPUError { constructor(message) { this.message = String(message ?? ''); } }
export class GPUValidationError extends GPUError {}
export class GPUOutOfMemoryError extends GPUError {}
export class GPUInternalError extends GPUError {}
export class GPUPipelineError extends Error {
  constructor(message, options) { super(message); this.name = 'GPUPipelineError'; this.reason = options?.reason ?? 'validation'; }
}

function makeError(type, message) {
  if (type === 'out-of-memory') return new GPUOutOfMemoryError(message);
  if (type === 'internal') return new GPUInternalError(message);
  return new GPUValidationError(message);
}

// ── event pump: uncaptured errors, device loss and async callbacks ──────────────────────────

const devicesById = new Map();
let pollTimer = null;

function pump() {
  const ev = native.takeEvents();
  for (const e of ev.errors) devicesById.get(e.device)?._dispatchError(makeError(e.type, e.message));
  for (const l of ev.lost) {
    const d = devicesById.get(l.device);
    if (d) d._markLost(l.reason, l.message);
  }
  if (ev.pending > 0) schedulePoll();
}

function schedulePoll() {
  if (pollTimer !== null) return;
  pollTimer = setTimeout(() => {
    pollTimer = null;
    let pending = 0;
    for (const d of devicesById.values()) pending = native.poll(d._n);
    if (devicesById.size === 0) pending = native.poll();
    pump();
    if (pending > 0) schedulePoll();
  }, 1);
}

/** Any live device (used to size camera frames before the engine imports them). */
export function anyDevice() {
  for (const d of devicesById.values()) return d;
  return null;
}

/** Called by the runtime once per frame so errors surface even without async work. */
export function pumpEvents() { pump(); }

// ── small helpers ────────────────────────────────────────────────────────────────────────────

class SimpleEventTarget {
  constructor() { this._listeners = new Map(); }
  addEventListener(type, fn, opts) {
    if (!fn) return;
    let set = this._listeners.get(type);
    if (!set) { set = new Map(); this._listeners.set(type, set); }
    set.set(fn, !!(opts && typeof opts === 'object' && opts.once));
  }
  removeEventListener(type, fn) { this._listeners.get(type)?.delete(fn); }
  dispatchEvent(ev) {
    const set = this._listeners.get(ev.type);
    if (set) {
      for (const [fn, once] of [...set]) {
        if (once) set.delete(fn);
        try { typeof fn === 'function' ? fn.call(this, ev) : fn.handleEvent(ev); } catch (e) { console.error('[webgpu] listener threw', e); }
      }
    }
    const prop = this['on' + ev.type];
    if (typeof prop === 'function') prop.call(this, ev);
    return !ev.defaultPrevented;
  }
}

class GPUSupportedFeatures extends Set {}

function byteView(data, dataOffset, size) {
  // WebGPU: offsets/sizes are in elements for typed arrays, in bytes for ArrayBuffer/DataView.
  if (ArrayBuffer.isView(data) && !(data instanceof DataView)) {
    const bpe = data.BYTES_PER_ELEMENT;
    const off = (dataOffset ?? 0) * bpe;
    const len = size !== undefined ? size * bpe : data.byteLength - off;
    return { buf: data, off, len };
  }
  const off = dataOffset ?? 0;
  const total = data.byteLength;
  return { buf: data, off, len: size !== undefined ? size : total - off };
}

// ── GPU / adapter ───────────────────────────────────────────────────────────────────────────

let preferredFormat = 'rgba8unorm';
export function setPreferredCanvasFormat(f) { preferredFormat = f; }

export class GPU {
  constructor() { this.wgslLanguageFeatures = new Set(); }
  async requestAdapter(options) {
    const n = native.requestAdapter(options ?? {});
    return n ? new GPUAdapter(n) : null;
  }
  getPreferredCanvasFormat() { return preferredFormat; }
}

export class GPUAdapterInfo {
  constructor(raw) {
    this.vendor = raw.vendor; this.architecture = raw.architecture;
    this.device = raw.device; this.description = raw.description;
    this.isFallbackAdapter = false; this.subgroupMinSize = 4; this.subgroupMaxSize = 128;
  }
}

export class GPUAdapter {
  constructor(n) {
    this._n = n;
    this.features = new GPUSupportedFeatures(native.adapterFeatures(n));
    this.limits = Object.freeze(native.adapterLimits(n));
    this.info = new GPUAdapterInfo(native.adapterInfo(n));
    this.isFallbackAdapter = false;
  }
  async requestAdapterInfo() { return this.info; }
  async requestDevice(desc) {
    const d = desc ?? {};
    const requiredLimits = {};
    for (const [k, v] of Object.entries(d.requiredLimits ?? {})) if (v !== undefined) requiredLimits[k] = v;
    const { device, id } = native.requestDevice(this._n, { label: d.label, requiredFeatures: [...(d.requiredFeatures ?? [])], requiredLimits });
    return new GPUDevice(device, id, this, d.label);
  }
}

// ── device ──────────────────────────────────────────────────────────────────────────────────

export class GPUDevice extends SimpleEventTarget {
  constructor(n, id, adapter, label) {
    super();
    this._n = n;
    this._id = id;
    this._adapterN = adapter._n;
    this.label = label ?? '';
    this.adapterInfo = adapter.info;
    this.features = new GPUSupportedFeatures(native.deviceFeatures(n));
    this.limits = Object.freeze(native.deviceLimits(n));
    this.queue = new GPUQueue(native.deviceQueue(n), this);
    this.onuncapturederror = null;
    this._isLost = false;
    this.lost = new Promise((resolve) => { this._resolveLost = resolve; });
    devicesById.set(id, this);
  }
  _dispatchError(error) {
    const ev = { type: 'uncapturederror', error, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; } };
    const unhandled = this.dispatchEvent(ev) && !this.onuncapturederror && !(this._listeners.get('uncapturederror')?.size);
    if (unhandled) console.warn('[webgpu] uncaptured', error.constructor.name, error.message);
  }
  _markLost(reason, message) {
    if (this._isLost) return;
    this._isLost = true;
    devicesById.delete(this._id);
    this._resolveLost({ reason, message });
  }
  destroy() {
    native.deviceDestroy(this._n);
    this._markLost('destroyed', 'Device was destroyed.');
  }

  createBuffer(desc) { return new GPUBuffer(native.createBuffer(this._n, desc), this, desc); }
  createTexture(desc) { return new GPUTexture(native.createTexture(this._n, desc), this, desc); }
  createSampler(desc) { return wrapObj(GPUSampler, native.createSampler(this._n, desc ?? {}), desc); }
  createShaderModule(desc) {
    const code = concretizeLiteralCalls(lowerExternalTextures(desc.code));
    return wrapObj(GPUShaderModule, native.createShaderModule(this._n, code === desc.code ? desc : { ...desc, code }), desc);
  }
  createBindGroupLayout(desc) { return wrapObj(GPUBindGroupLayout, native.createBindGroupLayout(this._n, desc), desc); }
  createPipelineLayout(desc) { return wrapObj(GPUPipelineLayout, native.createPipelineLayout(this._n, desc), desc); }
  createBindGroup(desc) { return wrapObj(GPUBindGroup, native.createBindGroup(this._n, desc), desc); }
  createRenderPipeline(desc) { return wrapObj(GPURenderPipeline, native.createRenderPipeline(this._n, desc), desc); }
  createComputePipeline(desc) { return wrapObj(GPUComputePipeline, native.createComputePipeline(this._n, desc), desc); }
  async createRenderPipelineAsync(desc) { return this._asyncPipeline(() => this.createRenderPipeline(desc)); }
  async createComputePipelineAsync(desc) { return this._asyncPipeline(() => this.createComputePipeline(desc)); }
  async _asyncPipeline(make) {
    native.pushErrorScope(this._n, 'validation');
    const p = make();
    const err = await this._popScope();
    if (err) throw new GPUPipelineError(err.message, { reason: 'validation' });
    return p;
  }
  createCommandEncoder(desc) { return wrapObj(GPUCommandEncoder, native.createCommandEncoder(this._n, desc ?? {}), desc); }
  createRenderBundleEncoder(desc) { return wrapObj(GPURenderBundleEncoder, native.createRenderBundleEncoder(this._n, desc), desc); }
  createQuerySet(desc) {
    const q = wrapObj(GPUQuerySet, native.createQuerySet(this._n, desc), desc);
    q.type = desc.type; q.count = desc.count;
    return q;
  }
  importExternalTexture(desc) {
    // No zero-copy video path here: the source supplies a regular texture refreshed per frame.
    const tex = desc.source?._gpuTexture?.(this);
    if (!tex) throw new TypeError('importExternalTexture: no frame available yet');
    const ext = tex.createView();
    ext.expired = false;
    return ext;
  }
  pushErrorScope(filter) { native.pushErrorScope(this._n, filter); }
  async popErrorScope() {
    const r = await this._popScope();
    return r ? makeError(r.type, r.message) : null;
  }
  _popScope() {
    const p = native.popErrorScope(this._n);
    schedulePoll();
    return p;
  }
}

// wgpu's Vulkan backend has no `texture_external`. Video sources are uploaded into ordinary RGBA
// textures (see importExternalTexture), so lower the WGSL type and its one-argument textureLoad.
function lowerExternalTextures(code) {
  if (typeof code !== 'string' || !code.includes('texture_external')) return code;
  // Globals (`var v: texture_external`) and function parameters (`t: texture_external`).
  const names = [...new Set([...code.matchAll(/([A-Za-z_][\w]*)\s*:\s*texture_external/g)].map((m) => m[1]))];
  let out = code.replace(/\btexture_external\b/g, 'texture_2d<f32>');
  for (const name of names) {
    let i = 0;
    const head = new RegExp(`textureLoad\\(\\s*${name}\\s*,`, 'g');
    let m;
    while ((m = head.exec(out)) !== null) {
      // Find the closing parenthesis of this call and append the mip level.
      let depth = 1, j = m.index + m[0].length;
      for (; j < out.length && depth > 0; j++) {
        if (out[j] === '(') depth++;
        else if (out[j] === ')') depth--;
      }
      const close = j - 1;
      out = `${out.slice(0, close)}, 0${out.slice(close)}`;
      head.lastIndex = close;
      if (++i > 1000) break;
    }
  }
  return out;
}

// naga cannot const-evaluate some builtins over abstract floats (`mix(0.05, 0.45, 0.85)` fails
// with "failed to convert expression to a concrete type"). When every argument of a call is a
// plain float literal, give the literals the f32 suffix — the value and type are unchanged.
const FLOAT_LIT = String.raw`-?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?`;
const LITERAL_CALL = new RegExp(String.raw`\b([A-Za-z_]\w*)\(\s*(${FLOAT_LIT}(?:\s*,\s*${FLOAT_LIT})*)\s*\)`, 'g');
function concretizeLiteralCalls(code) {
  if (typeof code !== 'string') return code;
  return code.replace(LITERAL_CALL, (m, fn, args) => {
    if (/^(vec\d|mat\d|array|f32|f16)/.test(fn)) return m;
    return `${fn}(${args.split(',').map((a) => `${a.trim()}f`).join(', ')})`;
  });
}

function wrapObj(Cls, n, desc) {
  const o = new Cls();
  o._n = n;
  o.label = desc?.label ?? '';
  return o;
}

// ── resources ───────────────────────────────────────────────────────────────────────────────

export class GPUBuffer {
  constructor(n, device, desc) {
    this._n = n;
    this._kind = 'buffer';
    this._device = device;
    this.label = desc.label ?? '';
    this.size = Number(desc.size);
    this.usage = desc.usage;
    this.mapState = desc.mappedAtCreation ? 'mapped' : 'unmapped';
    this._mapMode = desc.mappedAtCreation ? GPUMapMode.WRITE : 0;
    this._ranges = [];
    this._pendingMap = null;
  }
  mapAsync(mode, offset = 0, size) {
    if (this.mapState !== 'unmapped') return Promise.reject(new Error('OperationError: buffer is already mapped or pending'));
    const sz = size ?? Math.max(0, this.size - offset);
    this.mapState = 'pending';
    const p = native.bufferMapAsync(this._n, mode, offset, sz).then(() => {
      if (this.mapState !== 'pending') throw new Error('AbortError: mapping aborted');
      this.mapState = 'mapped';
      this._mapMode = mode;
    }, (e) => {
      this.mapState = 'unmapped';
      throw e;
    });
    schedulePoll();
    return p;
  }
  getMappedRange(offset = 0, size) {
    if (this.mapState !== 'mapped') throw new Error('OperationError: buffer is not mapped');
    const sz = size ?? Math.max(0, this.size - offset);
    let ab;
    if (this._mapMode & GPUMapMode.READ) {
      ab = native.bufferReadMapped(this._n, offset, sz);
    } else {
      ab = new ArrayBuffer(sz);
      if (this.usage & GPUBufferUsage.MAP_WRITE) {
        try { new Uint8Array(ab).set(new Uint8Array(native.bufferReadMapped(this._n, offset, sz))); } catch (_) { /* zero-filled */ }
      }
    }
    this._ranges.push({ offset, ab });
    return ab;
  }
  unmap() {
    if (this.mapState === 'pending') this.mapState = 'unmapped';
    if (this.mapState !== 'mapped') return;
    if (!(this._mapMode & GPUMapMode.READ)) {
      for (const r of this._ranges) native.bufferWriteMapped(this._n, r.offset, r.ab);
    }
    this._ranges = [];
    native.bufferUnmap(this._n);
    this.mapState = 'unmapped';
    this._mapMode = 0;
  }
  destroy() {
    if (this.mapState === 'mapped') { this._ranges = []; native.bufferUnmap(this._n); }
    this.mapState = 'unmapped';
    native.bufferDestroy(this._n);
  }
}

function extent3d(size) {
  if (Array.isArray(size)) return { width: size[0] ?? 1, height: size[1] ?? 1, depthOrArrayLayers: size[2] ?? 1 };
  return { width: size.width ?? 1, height: size.height ?? 1, depthOrArrayLayers: size.depthOrArrayLayers ?? 1 };
}

export class GPUTexture {
  constructor(n, device, desc) {
    this._n = n;
    this._kind = 'texture';
    this._device = device;
    this.label = desc.label ?? '';
    const e = extent3d(desc.size);
    this.width = e.width; this.height = e.height; this.depthOrArrayLayers = e.depthOrArrayLayers;
    this.mipLevelCount = desc.mipLevelCount ?? 1;
    this.sampleCount = desc.sampleCount ?? 1;
    this.dimension = desc.dimension ?? '2d';
    this.format = desc.format;
    this.usage = desc.usage;
    this._view = null;
  }
  get _defaultView() {
    if (!this._view) this._view = this.createView();
    return this._view;
  }
  createView(desc) {
    const v = wrapObj(GPUTextureView, native.createView(this._n, desc), desc);
    v._texture = this;
    return v;
  }
  destroy() { native.textureDestroy(this._n); }
}

export class GPUTextureView { constructor() { this._kind = 'view'; } }
export class GPUExternalTexture extends GPUTextureView {}
export class GPUSampler { constructor() { this._kind = 'sampler'; } }
export class GPUShaderModule {
  async getCompilationInfo() { return { messages: [] }; }
}
export class GPUBindGroupLayout {}
export class GPUPipelineLayout {}
export class GPUBindGroup {}
export class GPURenderPipeline {
  getBindGroupLayout(i) { return wrapObj(GPUBindGroupLayout, native.pipelineGetBindGroupLayout(this._n, i, false)); }
}
export class GPUComputePipeline {
  getBindGroupLayout(i) { return wrapObj(GPUBindGroupLayout, native.pipelineGetBindGroupLayout(this._n, i, true)); }
}
export class GPUQuerySet {
  destroy() { native.querySetDestroy(this._n); }
}
export class GPUCommandBuffer {}
export class GPURenderBundle {}

// ── encoders ────────────────────────────────────────────────────────────────────────────────

function setBindGroup(kind, pass, index, group, offsets, start, length) {
  let dyn = offsets;
  if (offsets && start !== undefined) dyn = Array.from(offsets).slice(start, start + length);
  else if (offsets && !Array.isArray(offsets)) dyn = Array.from(offsets);
  native.passSetBindGroup(kind, pass._n, index, group ? group._n : null, dyn);
}

export class GPUCommandEncoder {
  beginRenderPass(desc) { return wrapObj(GPURenderPassEncoder, native.beginRenderPass(this._n, desc), desc); }
  beginComputePass(desc) { return wrapObj(GPUComputePassEncoder, native.beginComputePass(this._n, desc ?? {}), desc); }
  copyBufferToBuffer(src, a, b, c, d) {
    // (src, srcOffset, dst, dstOffset, size?) or (src, dst, size?)
    if (typeof a === 'object') native.copyBufferToBuffer(this._n, src._n, 0, a._n, 0, b);
    else native.copyBufferToBuffer(this._n, src._n, a, b._n, c, d);
  }
  copyBufferToTexture(src, dst, size) { native.copyBufferToTexture(this._n, src, dst, size); }
  copyTextureToBuffer(src, dst, size) { native.copyTextureToBuffer(this._n, src, dst, size); }
  copyTextureToTexture(src, dst, size) { native.copyTextureToTexture(this._n, src, dst, size); }
  clearBuffer(buffer, offset, size) { native.clearBuffer(this._n, buffer._n, offset ?? 0, size); }
  resolveQuerySet(qs, first, count, dst, dstOffset) { native.resolveQuerySet(this._n, qs._n, first, count, dst._n, dstOffset); }
  writeTimestamp() {}
  pushDebugGroup() {}
  popDebugGroup() {}
  insertDebugMarker() {}
  finish(desc) { return wrapObj(GPUCommandBuffer, native.encoderFinish(this._n, desc ?? {}), desc); }
}

class RenderCommands {
  setPipeline(p) { native.passSetPipeline(this._kindId, this._n, p._n); }
  setBindGroup(i, g, o, s, l) { setBindGroup(this._kindId, this, i, g, o, s, l); }
  setVertexBuffer(slot, buffer, offset, size) { native.passSetVertexBuffer(this._kindId, this._n, slot, buffer ? buffer._n : null, offset ?? 0, size); }
  setIndexBuffer(buffer, format, offset, size) { native.passSetIndexBuffer(this._kindId, this._n, buffer._n, format, offset ?? 0, size); }
  draw(vc, ic, fv, fi) { native.passDraw(this._kindId, this._n, vc, ic ?? 1, fv ?? 0, fi ?? 0); }
  drawIndexed(ic, inst, fi, bv, fin) { native.passDrawIndexed(this._kindId, this._n, ic, inst ?? 1, fi ?? 0, bv ?? 0, fin ?? 0); }
  drawIndirect(b, o) { native.passDrawIndirect(this._kindId, this._n, b._n, o, false); }
  drawIndexedIndirect(b, o) { native.passDrawIndirect(this._kindId, this._n, b._n, o, true); }
  pushDebugGroup() {}
  popDebugGroup() {}
  insertDebugMarker() {}
}

export class GPURenderPassEncoder extends RenderCommands {
  get _kindId() { return RENDER; }
  setViewport(x, y, w, h, min, max) { native.passSetViewport(this._n, x, y, w, h, min, max); }
  setScissorRect(x, y, w, h) { native.passSetScissorRect(this._n, x, y, w, h); }
  setBlendConstant(c) { native.passSetBlendConstant(this._n, c); }
  setStencilReference(r) { native.passSetStencilReference(this._n, r); }
  beginOcclusionQuery(i) { native.passOcclusionQuery(this._n, i); }
  endOcclusionQuery() { native.passOcclusionQuery(this._n); }
  executeBundles(bundles) { native.passExecuteBundles(this._n, [...bundles]); }
  end() { native.passEnd(RENDER, this._n); }
}

export class GPURenderBundleEncoder extends RenderCommands {
  get _kindId() { return BUNDLE; }
  finish(desc) { return wrapObj(GPURenderBundle, native.renderBundleFinish(this._n, desc ?? {}), desc); }
}

export class GPUComputePassEncoder {
  setPipeline(p) { native.passSetPipeline(COMPUTE, this._n, p._n); }
  setBindGroup(i, g, o, s, l) { setBindGroup(COMPUTE, this, i, g, o, s, l); }
  dispatchWorkgroups(x, y, z) { native.passDispatch(this._n, x, y ?? 1, z ?? 1); }
  dispatchWorkgroupsIndirect(b, o) { native.passDispatchIndirect(this._n, b._n, o); }
  end() { native.passEnd(COMPUTE, this._n); }
  pushDebugGroup() {}
  popDebugGroup() {}
  insertDebugMarker() {}
}

// ── queue ───────────────────────────────────────────────────────────────────────────────────

export class GPUQueue {
  constructor(n, device) { this._n = n; this._device = device; this.label = ''; }
  submit(buffers) {
    native.queueSubmit(this._n, [...buffers].map((b) => b._n));
    pump();
  }
  writeBuffer(buffer, bufferOffset, data, dataOffset, size) {
    const v = byteView(data, dataOffset, size);
    native.queueWriteBuffer(this._n, buffer._n, bufferOffset, v.buf, v.off, v.len);
  }
  writeTexture(destination, data, dataLayout, size) {
    native.queueWriteTexture(this._n, destination, data, dataLayout, size);
  }
  onSubmittedWorkDone() {
    const p = native.queueOnSubmittedWorkDone(this._n);
    schedulePoll();
    return p;
  }
  copyExternalImageToTexture(source, destination, copySize) {
    const src = source.source ?? source;
    const img = src._rgba8?.();
    if (!img) throw new TypeError('copyExternalImageToTexture: unsupported source');
    const origin = source.origin ?? { x: 0, y: 0 };
    const ox = Array.isArray(origin) ? origin[0] ?? 0 : origin.x ?? 0;
    const oy = Array.isArray(origin) ? origin[1] ?? 0 : origin.y ?? 0;
    const e = extent3d(copySize);
    native.copyRGBA8ToTexture(this._n, img.data, img.width, img.height, ox, oy, destination, e.width, e.height,
      !!source.flipY, !!destination.premultipliedAlpha, destination.texture.format);
  }
}

// ── canvas context ──────────────────────────────────────────────────────────────────────────

/** WebGPU context for a SurfaceCanvas (see runtime.js). Presented by the runtime after each frame. */
export class GPUCanvasContext {
  constructor(canvas) {
    this.canvas = canvas;
    this._config = null;
    this._configured = { w: 0, h: 0 };
    this._frame = null;
  }
  configure(config) {
    this._config = { ...config };
    this._configured = { w: 0, h: 0 };
    this._apply();
  }
  unconfigure() {
    this._config = null;
    this._frame = null;
    if (this.canvas._surface) native.surfaceUnconfigure(this.canvas._surface);
  }
  getConfiguration() { return this._config; }
  _apply() {
    const s = this.canvas._surface;
    const c = this._config;
    if (!s || !c) return false;
    const w = Math.max(1, this.canvas.width | 0), h = Math.max(1, this.canvas.height | 0);
    if (this._configured.w === w && this._configured.h === h) return true;
    const caps = native.surfaceCapabilities(s, c.device._adapterN ?? null);
    let alphaMode = c.alphaMode ?? 'opaque';
    if (caps.alphaModes && caps.alphaModes.length && !caps.alphaModes.includes(alphaMode)) alphaMode = caps.alphaModes[0];
    native.surfaceConfigure(s, c.device._n, {
      format: c.format, usage: c.usage ?? GPUTextureUsage.RENDER_ATTACHMENT, width: w, height: h,
      alphaMode, viewFormats: c.viewFormats ?? [],
    });
    this._configured = { w, h };
    this._frame = null;
    return true;
  }
  getCurrentTexture() {
    if (!this._config) throw new Error('InvalidStateError: context is not configured');
    if (this._frame) return this._frame;
    if (!this._apply()) throw new Error('InvalidStateError: surface not ready');
    let r = native.surfaceGetCurrentTexture(this.canvas._surface);
    if (!r.texture) {
      // Outdated/lost swapchain (rotation, resize): reconfigure once and retry.
      this._configured = { w: 0, h: 0 };
      this._apply();
      r = native.surfaceGetCurrentTexture(this.canvas._surface);
    }
    if (!r.texture) throw new Error(`getCurrentTexture failed (status ${r.status})`);
    const c = this._config;
    this._frame = new GPUTexture(r.texture, c.device, {
      size: [this.canvas.width, this.canvas.height], format: c.format,
      usage: c.usage ?? GPUTextureUsage.RENDER_ATTACHMENT, label: 'canvas',
    });
    this._frame.destroy = () => {};
    this.canvas._onAcquire?.(this);
    return this._frame;
  }
  _present() {
    if (!this._frame) return false;
    this._frame = null;
    return native.surfacePresent(this.canvas._surface);
  }
  _invalidateSize() { this._configured = { w: 0, h: 0 }; }
}

export { native as gpuNative };

// ── video frames ────────────────────────────────────────────────────────────────────────────

const YUV_WGSL = `
@group(0) @binding(0) var yTex: texture_2d<f32>;
@group(0) @binding(1) var uvTex: texture_2d<f32>;
@group(0) @binding(2) var samp: sampler;
@group(0) @binding(3) var<uniform> opts: vec4f; // x: 1 = NV21 (CrCb order), y: 1 = BT.709
struct V { @builtin(position) pos: vec4f, @location(0) uv: vec2f }
@vertex fn vs(@builtin(vertex_index) i: u32) -> V {
  let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
  var o: V;
  o.pos = vec4f(p * 2.0 - 1.0, 0.0, 1.0);
  o.uv = vec2f(p.x, 1.0 - p.y);
  return o;
}
@fragment fn fs(v: V) -> @location(0) vec4f {
  let y = (textureSampleLevel(yTex, samp, v.uv, 0.0).r - 0.0627) * 1.1644;
  var c = textureSampleLevel(uvTex, samp, v.uv, 0.0).rg - vec2f(0.5);
  if (opts.x > 0.5) { c = c.yx; }
  let cb = c.x * 1.1384;
  let cr = c.y * 1.1384;
  var rgb: vec3f;
  if (opts.y > 0.5) {
    rgb = vec3f(y + 1.5748 * cr, y - 0.1873 * cb - 0.4681 * cr, y + 1.8556 * cb);
  } else {
    rgb = vec3f(y + 1.402 * cr, y - 0.3441 * cb - 0.7141 * cr, y + 1.772 * cb);
  }
  return vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), 1.0);
}`;

const yuvPipelines = new WeakMap();

function yuvPipeline(device) {
  let p = yuvPipelines.get(device);
  if (!p) {
    const module = device.createShaderModule({ code: YUV_WGSL, label: 'video-yuv' });
    const pipeline = device.createRenderPipeline({
      layout: 'auto', label: 'video-yuv',
      vertex: { module, entryPoint: 'vs' },
      fragment: { module, entryPoint: 'fs', targets: [{ format: 'rgba8unorm' }] },
    });
    const sampler = device.createSampler({ magFilter: 'linear', minFilter: 'linear' });
    p = { pipeline, sampler };
    yuvPipelines.set(device, p);
  }
  return p;
}

/**
 * Frames from a native consumer surface (AVPlayer or camera output), exposed to the engine as an
 * ordinary rgba8unorm texture that importExternalTexture hands out.
 */
export class VideoFrameSource {
  constructor() {
    const r = native.videoSurfaceCreate();
    if (!r) throw new Error('video surface unavailable');
    this._h = r.handle;
    this.surfaceId = r.surfaceId;
    this.width = 0;
    this.height = 0;
    this._dev = null;
    this._rgba = null;
    this._y = null;
    this._uv = null;
    this._bind = null;
    this._opts = null;
  }

  /** Pull the newest frame (if any) into the RGBA texture; returns it, or null before the first frame. */
  texture(device) {
    const info = native.videoAcquire(this._h);
    if (info && !String(info.format).startsWith('unsupported')) this._upload(device, info);
    else if (info) console.warn('[video] unsupported frame format', info.format);
    return this._rgba;
  }

  _upload(device, info) {
    const { width: w, height: h, format } = info;
    const yuv = format === 'nv12' || format === 'nv21';
    const outFormat = format === 'bgra' ? 'bgra8unorm' : 'rgba8unorm';
    if (this._dev !== device || this.width !== w || this.height !== h || (yuv && !this._y) || this._rgba?.format !== outFormat) {
      this._dev = device;
      this.width = w;
      this.height = h;
      const usage = GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT;
      this._rgba = device.createTexture({ size: [w, h], format: outFormat, usage, label: 'video' });
      this._y = this._uv = this._bind = null;
      if (yuv) {
        const tu = GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST;
        this._y = device.createTexture({ size: [w, h], format: 'r8unorm', usage: tu, label: 'video-y' });
        this._uv = device.createTexture({ size: [w >> 1, h >> 1], format: 'rg8unorm', usage: tu, label: 'video-uv' });
        const { pipeline, sampler } = yuvPipeline(device);
        this._opts = device.createBuffer({ size: 16, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
        this._bind = device.createBindGroup({
          layout: pipeline.getBindGroupLayout(0),
          entries: [
            { binding: 0, resource: this._y.createView() },
            { binding: 1, resource: this._uv.createView() },
            { binding: 2, resource: sampler },
            { binding: 3, resource: { buffer: this._opts } },
          ],
        });
      }
    }
    if (!yuv) {
      // RGBA/BGRA frames upload straight into a texture of the matching format.
      native.videoUpload(this._h, device.queue._n, this._rgba._n, null);
      return;
    }
    if (!native.videoUpload(this._h, device.queue._n, this._y._n, this._uv._n)) return;
    device.queue.writeBuffer(this._opts, 0, new Float32Array([format === 'nv21' ? 1 : 0, h >= 720 ? 1 : 0, 0, 0]));
    const enc = device.createCommandEncoder({ label: 'video-yuv' });
    const pass = enc.beginRenderPass({
      colorAttachments: [{ view: this._rgba.createView(), loadOp: 'clear', storeOp: 'store', clearValue: { r: 0, g: 0, b: 0, a: 1 } }],
    });
    pass.setPipeline(yuvPipeline(device).pipeline);
    pass.setBindGroup(0, this._bind);
    pass.draw(3);
    pass.end();
    device.queue.submit([enc.finish()]);
  }
}
