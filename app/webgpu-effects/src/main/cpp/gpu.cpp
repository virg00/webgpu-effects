// WebGPU for the Ark JS runtime, backed by wgpu-native (Vulkan).
//
// Native functions take plain JS descriptor objects (the same shapes the WebGPU IDL uses) and
// GPU objects either as raw externals or as the JS wrapper objects from webgpu.js, which keep
// their external in `_n`. Every external releases its wgpu handle when the GC collects it.

#include "enums.h"
#include "napi_util.h"
#include "webgpu.h"
#include "wgpu.h"

#include <hilog/log.h>
#include <native_buffer/native_buffer.h>
#include <native_image/native_image.h>
#include <native_window/external_window.h>
#include <sys/select.h>
#include <unistd.h>

#include <cmath>
#include <ctime>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x5348
#define LOG_TAG "webgpu-fx"

using namespace sg;

namespace {

WGPUInstance gInstance = nullptr;

WGPUStringView sv(const char *s) { return WGPUStringView{s, s ? strlen(s) : 0}; }
WGPUStringView sv(Arena &a, const std::string &s) { return WGPUStringView{a.keep(s), s.size()}; }
std::string fromSv(WGPUStringView v) {
    if (!v.data) return "";
    return v.length == WGPU_STRLEN ? std::string(v.data) : std::string(v.data, v.length);
}

WGPUInstance instance() {
    if (!gInstance) {
        wgpuSetLogCallback([](WGPULogLevel level, WGPUStringView message, void *) {
            std::string m = fromSv(message);
            if (level <= WGPULogLevel_Error) OH_LOG_ERROR(LOG_APP, "wgpu: %{public}s", m.c_str());
            else OH_LOG_WARN(LOG_APP, "wgpu: %{public}s", m.c_str());
        }, nullptr);
        wgpuSetLogLevel(WGPULogLevel_Warn);
        WGPUInstanceExtras extras = {};
        extras.chain.sType = (WGPUSType)WGPUSType_InstanceExtras;
        extras.backends = WGPUInstanceBackend_Vulkan;
        // The emulator's Vulkan (host GPU passthrough) reports no conformance version.
        extras.flags = WGPUInstanceFlag_AllowUnderlyingNoncompliantAdapter | WGPUInstanceFlag_DiscardHalLabels;
        WGPUInstanceDescriptor desc = {};
        desc.nextInChain = &extras.chain;
        gInstance = wgpuCreateInstance(&desc);
        if (!gInstance) OH_LOG_ERROR(LOG_APP, "wgpuCreateInstance failed");
    }
    return gInstance;
}

// ── externals ────────────────────────────────────────────────────────────────────────────────

template <typename T, void (*Release)(T)> napi_value wrap(napi_env env, T h) {
    napi_value v;
    if (!h) { napi_get_null(env, &v); return v; }
    napi_create_external(env, (void *)h, [](napi_env, void *data, void *) { Release((T)data); }, nullptr, &v);
    return v;
}

// Surfaces own their OHNativeWindow as well as the wgpu surface.
struct SurfaceRec {
    WGPUSurface surface = nullptr;
    OHNativeWindow *window = nullptr;
    WGPUTexture current = nullptr;
    bool configured = false;
};

// ── device bookkeeping: errors and loss are queued and drained by JS ────────────────────────

struct ErrorRec { int device; int type; std::string message; };
struct LostRec { int device; int reason; std::string message; };
std::vector<ErrorRec> gErrors;
std::vector<LostRec> gLost;
int gNextDeviceId = 1;
std::map<WGPUDevice, int> gDeviceIds;
int gPending = 0;  // outstanding async callbacks that need polling

const char *errorTypeName(WGPUErrorType t) {
    switch (t) {
    case WGPUErrorType_Validation: return "validation";
    case WGPUErrorType_OutOfMemory: return "out-of-memory";
    case WGPUErrorType_Internal: return "internal";
    default: return "unknown";
    }
}

// ── descriptor conversion ────────────────────────────────────────────────────────────────────

WGPUTextureFormat textureFormat(const std::string &s) { return lookup(kTextureFormats, s, WGPUTextureFormat_Undefined); }

WGPUExtent3D extent(Js &js, napi_value v) {
    WGPUExtent3D e = {1, 1, 1};
    if (!v) return e;
    if (js.isArray(v)) {
        uint32_t n = js.length(v);
        if (n > 0) e.width = js.u32(js.at(v, 0), 1);
        if (n > 1) e.height = js.u32(js.at(v, 1), 1);
        if (n > 2) e.depthOrArrayLayers = js.u32(js.at(v, 2), 1);
    } else {
        e.width = js.fu32(v, "width", 1);
        e.height = js.fu32(v, "height", 1);
        e.depthOrArrayLayers = js.fu32(v, "depthOrArrayLayers", 1);
    }
    return e;
}

WGPUOrigin3D origin(Js &js, napi_value v) {
    WGPUOrigin3D o = {0, 0, 0};
    if (!v) return o;
    if (js.isArray(v)) {
        uint32_t n = js.length(v);
        if (n > 0) o.x = js.u32(js.at(v, 0));
        if (n > 1) o.y = js.u32(js.at(v, 1));
        if (n > 2) o.z = js.u32(js.at(v, 2));
    } else {
        o.x = js.fu32(v, "x");
        o.y = js.fu32(v, "y");
        o.z = js.fu32(v, "z");
    }
    return o;
}

WGPUColor color(Js &js, napi_value v) {
    WGPUColor c = {0, 0, 0, 0};
    if (!v) return c;
    if (js.isArray(v)) {
        c.r = js.num(js.at(v, 0));
        c.g = js.num(js.at(v, 1));
        c.b = js.num(js.at(v, 2));
        c.a = js.num(js.at(v, 3));
    } else {
        c.r = js.fnum(v, "r");
        c.g = js.fnum(v, "g");
        c.b = js.fnum(v, "b");
        c.a = js.fnum(v, "a");
    }
    return c;
}

WGPUTexelCopyTextureInfo copyTexture(Js &js, napi_value v) {
    WGPUTexelCopyTextureInfo t = {};
    t.texture = js.handle<WGPUTexture>(js.get(v, "texture"));
    t.mipLevel = js.fu32(v, "mipLevel");
    t.origin = origin(js, js.get(v, "origin"));
    t.aspect = lookup(kAspects, js.fstr(v, "aspect", "all"), WGPUTextureAspect_All);
    return t;
}

WGPUTexelCopyBufferLayout bufferLayout(Js &js, napi_value v) {
    WGPUTexelCopyBufferLayout l = {};
    l.offset = js.fu64(v, "offset");
    l.bytesPerRow = js.fu32(v, "bytesPerRow", WGPU_COPY_STRIDE_UNDEFINED);
    l.rowsPerImage = js.fu32(v, "rowsPerImage", WGPU_COPY_STRIDE_UNDEFINED);
    return l;
}

WGPUConstantEntry *constants(Js &js, Arena &a, napi_value v, size_t &count) {
    count = 0;
    if (!v) return nullptr;
    napi_value keys;
    napi_get_property_names(js.env, v, &keys);
    uint32_t n = js.length(keys);
    auto *out = a.array<WGPUConstantEntry>(n);
    for (uint32_t i = 0; i < n; i++) {
        std::string k = js.str(js.at(keys, i));
        out[i].key = sv(a, k);
        out[i].value = js.fnum(v, k.c_str());
    }
    count = n;
    return out;
}

WGPUBlendComponent blendComponent(Js &js, napi_value v) {
    WGPUBlendComponent c = {WGPUBlendOperation_Add, WGPUBlendFactor_One, WGPUBlendFactor_Zero};
    if (!v) return c;
    c.operation = lookup(kBlendOps, js.fstr(v, "operation", "add"), WGPUBlendOperation_Add);
    c.srcFactor = lookup(kBlendFactors, js.fstr(v, "srcFactor", "one"), WGPUBlendFactor_One);
    c.dstFactor = lookup(kBlendFactors, js.fstr(v, "dstFactor", "zero"), WGPUBlendFactor_Zero);
    return c;
}

WGPUStencilFaceState stencilFace(Js &js, napi_value v) {
    WGPUStencilFaceState s = {WGPUCompareFunction_Always, WGPUStencilOperation_Keep, WGPUStencilOperation_Keep,
                              WGPUStencilOperation_Keep};
    if (!v) return s;
    s.compare = lookup(kCompareFunctions, js.fstr(v, "compare", "always"), WGPUCompareFunction_Always);
    s.failOp = lookup(kStencilOps, js.fstr(v, "failOp", "keep"), WGPUStencilOperation_Keep);
    s.depthFailOp = lookup(kStencilOps, js.fstr(v, "depthFailOp", "keep"), WGPUStencilOperation_Keep);
    s.passOp = lookup(kStencilOps, js.fstr(v, "passOp", "keep"), WGPUStencilOperation_Keep);
    return s;
}

std::string entryPoint(Js &js, napi_value stage) { return js.fstr(stage, "entryPoint"); }

WGPUStringView optionalEntry(Arena &a, const std::string &s) {
    if (s.empty()) return WGPUStringView{nullptr, WGPU_STRLEN};
    return sv(a, s);
}

void fillRenderPipeline(Js &js, Arena &a, napi_value d, WGPURenderPipelineDescriptor &desc) {
    desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    napi_value layout = js.get(d, "layout");
    desc.layout = (layout && js.type(layout) == napi_object) ? js.handle<WGPUPipelineLayout>(layout) : nullptr;

    napi_value vs = js.get(d, "vertex");
    desc.vertex.module = js.handle<WGPUShaderModule>(js.get(vs, "module"));
    desc.vertex.entryPoint = optionalEntry(a, entryPoint(js, vs));
    desc.vertex.constants = constants(js, a, js.get(vs, "constants"), desc.vertex.constantCount);
    napi_value buffers = js.get(vs, "buffers");
    uint32_t nb = js.length(buffers);
    auto *layouts = a.array<WGPUVertexBufferLayout>(nb);
    for (uint32_t i = 0; i < nb; i++) {
        napi_value b = js.at(buffers, i);
        if (!b) { layouts[i].stepMode = WGPUVertexStepMode_Undefined; continue; }
        layouts[i].arrayStride = js.fu64(b, "arrayStride");
        layouts[i].stepMode = lookup(kStepModes, js.fstr(b, "stepMode", "vertex"), WGPUVertexStepMode_Vertex);
        napi_value attrs = js.get(b, "attributes");
        uint32_t na = js.length(attrs);
        auto *at = a.array<WGPUVertexAttribute>(na);
        for (uint32_t j = 0; j < na; j++) {
            napi_value av = js.at(attrs, j);
            at[j].format = lookup(kVertexFormats, js.fstr(av, "format"), WGPUVertexFormat_Float32);
            at[j].offset = js.fu64(av, "offset");
            at[j].shaderLocation = js.fu32(av, "shaderLocation");
        }
        layouts[i].attributeCount = na;
        layouts[i].attributes = at;
    }
    desc.vertex.bufferCount = nb;
    desc.vertex.buffers = layouts;

    napi_value prim = js.get(d, "primitive");
    desc.primitive.topology = lookup(kTopologies, js.fstr(prim, "topology", "triangle-list"), WGPUPrimitiveTopology_TriangleList);
    desc.primitive.stripIndexFormat = lookup(kIndexFormats, js.fstr(prim, "stripIndexFormat"), WGPUIndexFormat_Undefined);
    desc.primitive.frontFace = lookup(kFrontFaces, js.fstr(prim, "frontFace", "ccw"), WGPUFrontFace_CCW);
    desc.primitive.cullMode = lookup(kCullModes, js.fstr(prim, "cullMode", "none"), WGPUCullMode_None);
    desc.primitive.unclippedDepth = js.fbool(prim, "unclippedDepth");

    napi_value ds = js.get(d, "depthStencil");
    if (ds) {
        auto *s = a.one<WGPUDepthStencilState>();
        s->format = textureFormat(js.fstr(ds, "format"));
        napi_value dwe = js.get(ds, "depthWriteEnabled");
        s->depthWriteEnabled = dwe ? (js.boolean(dwe) ? WGPUOptionalBool_True : WGPUOptionalBool_False) : WGPUOptionalBool_Undefined;
        std::string cmp = js.fstr(ds, "depthCompare");
        s->depthCompare = lookup(kCompareFunctions, cmp, WGPUCompareFunction_Undefined);
        s->stencilFront = stencilFace(js, js.get(ds, "stencilFront"));
        s->stencilBack = stencilFace(js, js.get(ds, "stencilBack"));
        s->stencilReadMask = js.fu32(ds, "stencilReadMask", 0xFFFFFFFF);
        s->stencilWriteMask = js.fu32(ds, "stencilWriteMask", 0xFFFFFFFF);
        s->depthBias = js.i32(js.get(ds, "depthBias"));
        s->depthBiasSlopeScale = (float)js.fnum(ds, "depthBiasSlopeScale");
        s->depthBiasClamp = (float)js.fnum(ds, "depthBiasClamp");
        desc.depthStencil = s;
    }

    napi_value ms = js.get(d, "multisample");
    desc.multisample.count = js.fu32(ms, "count", 1);
    desc.multisample.mask = js.fu32(ms, "mask", 0xFFFFFFFF);
    desc.multisample.alphaToCoverageEnabled = js.fbool(ms, "alphaToCoverageEnabled");

    napi_value fs = js.get(d, "fragment");
    if (fs) {
        auto *f = a.one<WGPUFragmentState>();
        f->module = js.handle<WGPUShaderModule>(js.get(fs, "module"));
        f->entryPoint = optionalEntry(a, entryPoint(js, fs));
        f->constants = constants(js, a, js.get(fs, "constants"), f->constantCount);
        napi_value targets = js.get(fs, "targets");
        uint32_t nt = js.length(targets);
        auto *ts = a.array<WGPUColorTargetState>(nt);
        for (uint32_t i = 0; i < nt; i++) {
            napi_value t = js.at(targets, i);
            if (!t) { ts[i].format = WGPUTextureFormat_Undefined; continue; }
            ts[i].format = textureFormat(js.fstr(t, "format"));
            ts[i].writeMask = js.fu32(t, "writeMask", WGPUColorWriteMask_All);
            napi_value blend = js.get(t, "blend");
            if (blend) {
                auto *b = a.one<WGPUBlendState>();
                b->color = blendComponent(js, js.get(blend, "color"));
                b->alpha = blendComponent(js, js.get(blend, "alpha"));
                ts[i].blend = b;
            }
        }
        f->targetCount = nt;
        f->targets = ts;
        desc.fragment = f;
    }
}

void fillComputePipeline(Js &js, Arena &a, napi_value d, WGPUComputePipelineDescriptor &desc) {
    desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    napi_value layout = js.get(d, "layout");
    desc.layout = (layout && js.type(layout) == napi_object) ? js.handle<WGPUPipelineLayout>(layout) : nullptr;
    napi_value cs = js.get(d, "compute");
    desc.compute.module = js.handle<WGPUShaderModule>(js.get(cs, "module"));
    desc.compute.entryPoint = optionalEntry(a, entryPoint(js, cs));
    desc.compute.constants = constants(js, a, js.get(cs, "constants"), desc.compute.constantCount);
}

WGPUPassTimestampWrites *timestampWrites(Js &js, Arena &a, napi_value v) {
    if (!v) return nullptr;
    auto *t = a.one<WGPUPassTimestampWrites>();
    t->querySet = js.handle<WGPUQuerySet>(js.get(v, "querySet"));
    t->beginningOfPassWriteIndex = js.fu32(v, "beginningOfPassWriteIndex", WGPU_QUERY_SET_INDEX_UNDEFINED);
    t->endOfPassWriteIndex = js.fu32(v, "endOfPassWriteIndex", WGPU_QUERY_SET_INDEX_UNDEFINED);
    return t;
}

napi_value limitsToJs(Js &js, const WGPULimits &l) {
    napi_value o = js.mkObj();
#define L(name) js.set(o, #name, js.mkNum((double)l.name));
    L(maxTextureDimension1D) L(maxTextureDimension2D) L(maxTextureDimension3D) L(maxTextureArrayLayers) L(maxBindGroups)
    L(maxBindGroupsPlusVertexBuffers) L(maxBindingsPerBindGroup) L(maxDynamicUniformBuffersPerPipelineLayout)
    L(maxDynamicStorageBuffersPerPipelineLayout) L(maxSampledTexturesPerShaderStage) L(maxSamplersPerShaderStage)
    L(maxStorageBuffersPerShaderStage) L(maxStorageTexturesPerShaderStage) L(maxUniformBuffersPerShaderStage)
    L(maxUniformBufferBindingSize) L(maxStorageBufferBindingSize) L(minUniformBufferOffsetAlignment)
    L(minStorageBufferOffsetAlignment) L(maxVertexBuffers) L(maxBufferSize) L(maxVertexAttributes)
    L(maxVertexBufferArrayStride) L(maxInterStageShaderVariables) L(maxColorAttachments) L(maxColorAttachmentBytesPerSample)
    L(maxComputeWorkgroupStorageSize) L(maxComputeInvocationsPerWorkgroup) L(maxComputeWorkgroupSizeX)
    L(maxComputeWorkgroupSizeY) L(maxComputeWorkgroupSizeZ) L(maxComputeWorkgroupsPerDimension)
#undef L
    return o;
}

void limitsFromJs(Js &js, napi_value o, WGPULimits &l) {
    l = {};
    memset(&l, 0xFF, sizeof(l));  // every field "undefined"
    l.nextInChain = nullptr;
    l.maxImmediateSize = WGPU_LIMIT_U32_UNDEFINED;
    if (!o) return;
#define L32(name) if (js.has(o, #name)) l.name = js.fu32(o, #name);
#define L64(name) if (js.has(o, #name)) l.name = js.fu64(o, #name);
    L32(maxTextureDimension1D) L32(maxTextureDimension2D) L32(maxTextureDimension3D) L32(maxTextureArrayLayers)
    L32(maxBindGroups) L32(maxBindGroupsPlusVertexBuffers) L32(maxBindingsPerBindGroup)
    L32(maxDynamicUniformBuffersPerPipelineLayout) L32(maxDynamicStorageBuffersPerPipelineLayout)
    L32(maxSampledTexturesPerShaderStage) L32(maxSamplersPerShaderStage) L32(maxStorageBuffersPerShaderStage)
    L32(maxStorageTexturesPerShaderStage) L32(maxUniformBuffersPerShaderStage) L64(maxUniformBufferBindingSize)
    L64(maxStorageBufferBindingSize) L32(minUniformBufferOffsetAlignment) L32(minStorageBufferOffsetAlignment)
    L32(maxVertexBuffers) L64(maxBufferSize) L32(maxVertexAttributes) L32(maxVertexBufferArrayStride)
    L32(maxInterStageShaderVariables) L32(maxColorAttachments) L32(maxColorAttachmentBytesPerSample)
    L32(maxComputeWorkgroupStorageSize) L32(maxComputeInvocationsPerWorkgroup) L32(maxComputeWorkgroupSizeX)
    L32(maxComputeWorkgroupSizeY) L32(maxComputeWorkgroupSizeZ) L32(maxComputeWorkgroupsPerDimension)
#undef L32
#undef L64
}

napi_value featuresToJs(Js &js, const WGPUSupportedFeatures &f) {
    napi_value arr = js.mkArr();
    for (size_t i = 0; i < f.featureCount; i++) {
        const char *n = nameOf(kFeatures, f.features[i]);
        if (n) js.push(arr, js.mkStr(n));
    }
    return arr;
}

// ── promise plumbing for async wgpu callbacks (fired from poll() on the JS thread) ───────────

struct Pending {
    napi_env env;
    napi_deferred deferred;
};

Pending *newPending(napi_env env, napi_value *promise) {
    auto *p = new Pending{env, nullptr};
    napi_create_promise(env, &p->deferred, promise);
    gPending++;
    return p;
}

void settle(Pending *p, bool ok, napi_value value) {
    gPending--;
    if (ok) napi_resolve_deferred(p->env, p->deferred, value);
    else napi_reject_deferred(p->env, p->deferred, value);
    delete p;
}

napi_value errorValue(napi_env env, const std::string &msg) {
    napi_value m, e;
    napi_create_string_utf8(env, msg.c_str(), msg.size(), &m);
    napi_create_error(env, nullptr, m, &e);
    return e;
}

} // namespace

// ═════════════════════════════════════════════════════════════════════════════════════════════
// Adapter / device
// ═════════════════════════════════════════════════════════════════════════════════════════════

static napi_value RequestAdapter(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPURequestAdapterOptions opts = {};
    std::string pp = js.fstr(args[0], "powerPreference");
    opts.powerPreference = pp == "low-power" ? WGPUPowerPreference_LowPower
                         : pp == "high-performance" ? WGPUPowerPreference_HighPerformance
                                                    : WGPUPowerPreference_Undefined;
    opts.forceFallbackAdapter = js.fbool(args[0], "forceFallbackAdapter");
    opts.backendType = WGPUBackendType_Vulkan;
    struct Result { WGPUAdapter adapter = nullptr; std::string message; bool done = false; } result;
    WGPURequestAdapterCallbackInfo cb = {};
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = [](WGPURequestAdapterStatus status, WGPUAdapter adapter, WGPUStringView message, void *u1, void *) {
        auto *r = (Result *)u1;
        r->done = true;
        if (status == WGPURequestAdapterStatus_Success) r->adapter = adapter;
        else r->message = fromSv(message);
    };
    cb.userdata1 = &result;
    WGPUInstance inst = instance();
    if (!inst) return js.null();
    wgpuInstanceRequestAdapter(inst, &opts, cb);
    for (int i = 0; i < 1000 && !result.done; i++) wgpuInstanceProcessEvents(inst);
    if (!result.adapter) {
        OH_LOG_WARN(LOG_APP, "requestAdapter: %{public}s", result.message.c_str());
        return js.null();
    }
    return wrap<WGPUAdapter, wgpuAdapterRelease>(env, result.adapter);
}

static napi_value AdapterInfo(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUAdapterInfo ai = {};
    wgpuAdapterGetInfo(js.handle<WGPUAdapter>(args[0]), &ai);
    napi_value o = js.mkObj();
    js.set(o, "vendor", js.mkStr(fromSv(ai.vendor)));
    js.set(o, "architecture", js.mkStr(fromSv(ai.architecture)));
    js.set(o, "device", js.mkStr(fromSv(ai.device)));
    js.set(o, "description", js.mkStr(fromSv(ai.description)));
    js.set(o, "vendorID", js.mkNum(ai.vendorID));
    js.set(o, "deviceID", js.mkNum(ai.deviceID));
    js.set(o, "adapterType", js.mkNum(ai.adapterType));
    wgpuAdapterInfoFreeMembers(ai);
    return o;
}

static napi_value AdapterLimits(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPULimits l = {};
    wgpuAdapterGetLimits(js.handle<WGPUAdapter>(args[0]), &l);
    return limitsToJs(js, l);
}

static napi_value AdapterFeatures(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUSupportedFeatures f = {};
    wgpuAdapterGetFeatures(js.handle<WGPUAdapter>(args[0]), &f);
    napi_value r = featuresToJs(js, f);
    wgpuSupportedFeaturesFreeMembers(f);
    return r;
}

// requestDevice(adapter, desc) -> {device, id} ; throws on failure
static napi_value RequestDevice(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUAdapter adapter = js.handle<WGPUAdapter>(args[0]);
    napi_value d = args[1];
    WGPUDeviceDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    napi_value feats = js.get(d, "requiredFeatures");
    uint32_t nf = js.length(feats);
    auto *fs = a.array<WGPUFeatureName>(nf);
    size_t count = 0;
    for (uint32_t i = 0; i < nf; i++) {
        auto f = lookup(kFeatures, js.str(js.at(feats, i)), (WGPUFeatureName)0);
        if (f) fs[count++] = f;
    }
    desc.requiredFeatureCount = count;
    desc.requiredFeatures = fs;
    WGPULimits limits;
    limitsFromJs(js, js.get(d, "requiredLimits"), limits);
    desc.requiredLimits = &limits;
    int id = gNextDeviceId++;
    desc.uncapturedErrorCallbackInfo.callback = [](WGPUDevice const *, WGPUErrorType type, WGPUStringView message, void *u1, void *) {
        std::string msg = fromSv(message);
        OH_LOG_WARN(LOG_APP, "uncaptured %{public}s: %{public}s", errorTypeName(type), msg.substr(0, 3000).c_str());
        gErrors.push_back({(int)(intptr_t)u1, (int)type, msg});
    };
    desc.uncapturedErrorCallbackInfo.userdata1 = (void *)(intptr_t)id;
    desc.deviceLostCallbackInfo.mode = WGPUCallbackMode_AllowSpontaneous;
    desc.deviceLostCallbackInfo.callback = [](WGPUDevice const *, WGPUDeviceLostReason reason, WGPUStringView message, void *u1, void *) {
        gLost.push_back({(int)(intptr_t)u1, (int)reason, fromSv(message)});
    };
    desc.deviceLostCallbackInfo.userdata1 = (void *)(intptr_t)id;

    struct Result { WGPUDevice device = nullptr; std::string message; bool done = false; } result;
    WGPURequestDeviceCallbackInfo cb = {};
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = [](WGPURequestDeviceStatus status, WGPUDevice device, WGPUStringView message, void *u1, void *) {
        auto *r = (Result *)u1;
        r->done = true;
        if (status == WGPURequestDeviceStatus_Success) r->device = device;
        else r->message = fromSv(message);
    };
    cb.userdata1 = &result;
    wgpuAdapterRequestDevice(adapter, &desc, cb);
    for (int i = 0; i < 1000 && !result.done; i++) wgpuInstanceProcessEvents(instance());
    if (!result.device) {
        OH_LOG_ERROR(LOG_APP, "requestDevice failed: %{public}s", result.message.c_str());
        js.throwError("requestDevice failed: " + result.message);
        return nullptr;
    }
    gDeviceIds[result.device] = id;
    napi_value o = js.mkObj();
    js.set(o, "device", wrap<WGPUDevice, wgpuDeviceRelease>(env, result.device));
    js.set(o, "id", js.mkNum(id));
    return o;
}

static napi_value DeviceLimits(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPULimits l = {};
    wgpuDeviceGetLimits(js.handle<WGPUDevice>(args[0]), &l);
    return limitsToJs(js, l);
}

static napi_value DeviceFeatures(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUSupportedFeatures f = {};
    wgpuDeviceGetFeatures(js.handle<WGPUDevice>(args[0]), &f);
    napi_value r = featuresToJs(js, f);
    wgpuSupportedFeaturesFreeMembers(f);
    return r;
}

static napi_value DeviceQueue(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    return wrap<WGPUQueue, wgpuQueueRelease>(env, wgpuDeviceGetQueue(js.handle<WGPUDevice>(args[0])));
}

static napi_value DeviceDestroy(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUDevice d = js.handle<WGPUDevice>(args[0]);
    if (d) wgpuDeviceDestroy(d);
    return nullptr;
}

// Drains queued uncaptured errors and device-loss notices: {errors:[{device,type,message}], lost:[...]}
static napi_value TakeEvents(napi_env env, napi_callback_info) {
    Js js(env);
    napi_value o = js.mkObj();
    napi_value errs = js.mkArr();
    for (auto &e : gErrors) {
        napi_value r = js.mkObj();
        js.set(r, "device", js.mkNum(e.device));
        js.set(r, "type", js.mkStr(errorTypeName((WGPUErrorType)e.type)));
        js.set(r, "message", js.mkStr(e.message));
        js.push(errs, r);
    }
    gErrors.clear();
    napi_value lost = js.mkArr();
    for (auto &l : gLost) {
        napi_value r = js.mkObj();
        js.set(r, "device", js.mkNum(l.device));
        js.set(r, "reason", js.mkStr(l.reason == WGPUDeviceLostReason_Destroyed ? "destroyed" : "unknown"));
        js.set(r, "message", js.mkStr(l.message));
        js.push(lost, r);
    }
    gLost.clear();
    js.set(o, "errors", errs);
    js.set(o, "lost", lost);
    js.set(o, "pending", js.mkNum(gPending));
    return o;
}

// poll(device?) — drives mapAsync / onSubmittedWorkDone / popErrorScope callbacks.
static napi_value Poll(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUDevice d = js.handle<WGPUDevice>(args[0]);
    if (d) wgpuDevicePoll(d, false, nullptr);
    if (gInstance) wgpuInstanceProcessEvents(gInstance);
    return js.mkNum(gPending);
}

static napi_value PushErrorScope(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuDevicePushErrorScope(js.handle<WGPUDevice>(args[0]),
                             lookup(kErrorFilters, js.str(args[1]), WGPUErrorFilter_Validation));
    return nullptr;
}

// popErrorScope(device) -> Promise<{type,message}|null>
static napi_value PopErrorScope(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    napi_value promise;
    Pending *p = newPending(env, &promise);
    WGPUPopErrorScopeCallbackInfo cb = {};
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = [](WGPUPopErrorScopeStatus status, WGPUErrorType type, WGPUStringView message, void *u1, void *) {
        auto *p = (Pending *)u1;
        Js js(p->env);
        if (status != WGPUPopErrorScopeStatus_Success) {
            settle(p, false, errorValue(p->env, "popErrorScope failed: " + fromSv(message)));
            return;
        }
        if (type == WGPUErrorType_NoError) { settle(p, true, js.null()); return; }
        napi_value o = js.mkObj();
        js.set(o, "type", js.mkStr(errorTypeName(type)));
        js.set(o, "message", js.mkStr(fromSv(message)));
        settle(p, true, o);
    };
    cb.userdata1 = p;
    wgpuDevicePopErrorScope(js.handle<WGPUDevice>(args[0]), cb);
    wgpuInstanceProcessEvents(instance());
    return promise;
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// Resources
// ═════════════════════════════════════════════════════════════════════════════════════════════

static napi_value CreateBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPUBufferDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.usage = js.fu64(d, "usage");
    desc.size = js.fu64(d, "size");
    desc.mappedAtCreation = js.fbool(d, "mappedAtCreation");
    return wrap<WGPUBuffer, wgpuBufferRelease>(env, wgpuDeviceCreateBuffer(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value BufferDestroy(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[0]);
    if (b) wgpuBufferDestroy(b);
    return nullptr;
}

// bufferMapAsync(buffer, mode, offset, size) -> Promise<void>
static napi_value BufferMapAsync(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    napi_value promise;
    Pending *p = newPending(env, &promise);
    WGPUBufferMapCallbackInfo cb = {};
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = [](WGPUMapAsyncStatus status, WGPUStringView message, void *u1, void *) {
        auto *p = (Pending *)u1;
        Js js(p->env);
        if (status == WGPUMapAsyncStatus_Success) settle(p, true, js.undefined());
        else settle(p, false, errorValue(p->env, "mapAsync failed: " + fromSv(message)));
    };
    cb.userdata1 = p;
    WGPUBuffer b = js.handle<WGPUBuffer>(args[0]);
    uint64_t size = js.u64(args[3], WGPU_WHOLE_MAP_SIZE);
    wgpuBufferMapAsync(b, (WGPUMapMode)js.u64(args[1]), (size_t)js.u64(args[2]), size == WGPU_WHOLE_SIZE ? WGPU_WHOLE_MAP_SIZE : (size_t)size, cb);
    return promise;
}

// bufferReadMapped(buffer, offset, size) -> ArrayBuffer copy of the mapped range
static napi_value BufferReadMapped(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[0]);
    size_t offset = (size_t)js.u64(args[1]);
    size_t size = (size_t)js.u64(args[2]);
    void *out = nullptr;
    napi_value ab;
    napi_create_arraybuffer(env, size, &out, &ab);
    const void *src = wgpuBufferGetConstMappedRange(b, offset, size);
    if (src && out) memcpy(out, src, size);
    return ab;
}

// bufferWriteMapped(buffer, offset, arrayBuffer) — copies a JS-side mapped range back before unmap
static napi_value BufferWriteMapped(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[0]);
    size_t offset = (size_t)js.u64(args[1]);
    uint8_t *data; size_t len;
    if (!js.bytes(args[2], data, len)) return nullptr;
    void *dst = wgpuBufferGetMappedRange(b, offset, len);
    if (dst) memcpy(dst, data, len);
    return nullptr;
}

static napi_value BufferUnmap(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuBufferUnmap(js.handle<WGPUBuffer>(args[0]));
    return nullptr;
}

static napi_value CreateTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPUTextureDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.usage = js.fu64(d, "usage");
    desc.dimension = lookup(kDimensions, js.fstr(d, "dimension", "2d"), WGPUTextureDimension_2D);
    desc.size = extent(js, js.get(d, "size"));
    desc.format = textureFormat(js.fstr(d, "format"));
    desc.mipLevelCount = js.fu32(d, "mipLevelCount", 1);
    desc.sampleCount = js.fu32(d, "sampleCount", 1);
    napi_value vf = js.get(d, "viewFormats");
    uint32_t n = js.length(vf);
    auto *formats = a.array<WGPUTextureFormat>(n);
    for (uint32_t i = 0; i < n; i++) formats[i] = textureFormat(js.str(js.at(vf, i)));
    desc.viewFormatCount = n;
    desc.viewFormats = formats;
    return wrap<WGPUTexture, wgpuTextureRelease>(env, wgpuDeviceCreateTexture(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value TextureDestroy(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUTexture t = js.handle<WGPUTexture>(args[0]);
    if (t) wgpuTextureDestroy(t);
    return nullptr;
}

static napi_value CreateView(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUTexture t = js.handle<WGPUTexture>(args[0]);
    napi_value d = args[1];
    if (!d) return wrap<WGPUTextureView, wgpuTextureViewRelease>(env, wgpuTextureCreateView(t, nullptr));
    WGPUTextureViewDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.format = textureFormat(js.fstr(d, "format"));
    desc.dimension = lookup(kViewDimensions, js.fstr(d, "dimension"), WGPUTextureViewDimension_Undefined);
    desc.baseMipLevel = js.fu32(d, "baseMipLevel");
    desc.mipLevelCount = js.fu32(d, "mipLevelCount", WGPU_MIP_LEVEL_COUNT_UNDEFINED);
    desc.baseArrayLayer = js.fu32(d, "baseArrayLayer");
    desc.arrayLayerCount = js.fu32(d, "arrayLayerCount", WGPU_ARRAY_LAYER_COUNT_UNDEFINED);
    desc.aspect = lookup(kAspects, js.fstr(d, "aspect", "all"), WGPUTextureAspect_All);
    desc.usage = js.fu64(d, "usage");
    return wrap<WGPUTextureView, wgpuTextureViewRelease>(env, wgpuTextureCreateView(t, &desc));
}

static napi_value CreateSampler(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPUSamplerDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.addressModeU = lookup(kAddressModes, js.fstr(d, "addressModeU", "clamp-to-edge"), WGPUAddressMode_ClampToEdge);
    desc.addressModeV = lookup(kAddressModes, js.fstr(d, "addressModeV", "clamp-to-edge"), WGPUAddressMode_ClampToEdge);
    desc.addressModeW = lookup(kAddressModes, js.fstr(d, "addressModeW", "clamp-to-edge"), WGPUAddressMode_ClampToEdge);
    desc.magFilter = lookup(kFilterModes, js.fstr(d, "magFilter", "nearest"), WGPUFilterMode_Nearest);
    desc.minFilter = lookup(kFilterModes, js.fstr(d, "minFilter", "nearest"), WGPUFilterMode_Nearest);
    desc.mipmapFilter = lookup(kMipmapFilterModes, js.fstr(d, "mipmapFilter", "nearest"), WGPUMipmapFilterMode_Nearest);
    desc.lodMinClamp = (float)js.fnum(d, "lodMinClamp", 0);
    desc.lodMaxClamp = (float)js.fnum(d, "lodMaxClamp", 32);
    desc.compare = lookup(kCompareFunctions, js.fstr(d, "compare"), WGPUCompareFunction_Undefined);
    desc.maxAnisotropy = (uint16_t)js.fu32(d, "maxAnisotropy", 1);
    return wrap<WGPUSampler, wgpuSamplerRelease>(env, wgpuDeviceCreateSampler(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreateShaderModule(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPUShaderSourceWGSL src = {};
    src.chain.sType = WGPUSType_ShaderSourceWGSL;
    src.code = sv(a, js.fstr(d, "code"));
    WGPUShaderModuleDescriptor desc = {};
    desc.nextInChain = &src.chain;
    desc.label = sv(a, js.fstr(d, "label"));
    return wrap<WGPUShaderModule, wgpuShaderModuleRelease>(env, wgpuDeviceCreateShaderModule(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreateBindGroupLayout(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    napi_value entries = js.get(d, "entries");
    uint32_t n = js.length(entries);
    auto *es = a.array<WGPUBindGroupLayoutEntry>(n);
    for (uint32_t i = 0; i < n; i++) {
        napi_value e = js.at(entries, i);
        es[i].binding = js.fu32(e, "binding");
        es[i].visibility = js.fu64(e, "visibility");
        if (napi_value b = js.get(e, "buffer")) {
            es[i].buffer.type = lookup(kBufferBindingTypes, js.fstr(b, "type", "uniform"), WGPUBufferBindingType_Uniform);
            es[i].buffer.hasDynamicOffset = js.fbool(b, "hasDynamicOffset");
            es[i].buffer.minBindingSize = js.fu64(b, "minBindingSize");
        }
        if (napi_value s = js.get(e, "sampler")) {
            es[i].sampler.type = lookup(kSamplerBindingTypes, js.fstr(s, "type", "filtering"), WGPUSamplerBindingType_Filtering);
        }
        if (napi_value t = js.get(e, "texture")) {
            es[i].texture.sampleType = lookup(kSampleTypes, js.fstr(t, "sampleType", "float"), WGPUTextureSampleType_Float);
            es[i].texture.viewDimension = lookup(kViewDimensions, js.fstr(t, "viewDimension", "2d"), WGPUTextureViewDimension_2D);
            es[i].texture.multisampled = js.fbool(t, "multisampled");
        }
        if (napi_value t = js.get(e, "storageTexture")) {
            es[i].storageTexture.access = lookup(kStorageAccess, js.fstr(t, "access", "write-only"), WGPUStorageTextureAccess_WriteOnly);
            es[i].storageTexture.format = textureFormat(js.fstr(t, "format"));
            es[i].storageTexture.viewDimension = lookup(kViewDimensions, js.fstr(t, "viewDimension", "2d"), WGPUTextureViewDimension_2D);
        }
        if (js.get(e, "externalTexture")) {
            // External textures are lowered to plain sampled 2D textures (see webgpu.js importExternalTexture).
            es[i].texture.sampleType = WGPUTextureSampleType_Float;
            es[i].texture.viewDimension = WGPUTextureViewDimension_2D;
        }
    }
    WGPUBindGroupLayoutDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.entryCount = n;
    desc.entries = es;
    return wrap<WGPUBindGroupLayout, wgpuBindGroupLayoutRelease>(env, wgpuDeviceCreateBindGroupLayout(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreatePipelineLayout(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    napi_value layouts = js.get(d, "bindGroupLayouts");
    uint32_t n = js.length(layouts);
    auto *ls = a.array<WGPUBindGroupLayout>(n);
    for (uint32_t i = 0; i < n; i++) ls[i] = js.handle<WGPUBindGroupLayout>(js.at(layouts, i));
    WGPUPipelineLayoutDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.bindGroupLayoutCount = n;
    desc.bindGroupLayouts = ls;
    return wrap<WGPUPipelineLayout, wgpuPipelineLayoutRelease>(env, wgpuDeviceCreatePipelineLayout(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreateBindGroup(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    napi_value entries = js.get(d, "entries");
    uint32_t n = js.length(entries);
    auto *es = a.array<WGPUBindGroupEntry>(n);
    for (uint32_t i = 0; i < n; i++) {
        napi_value e = js.at(entries, i);
        es[i].binding = js.fu32(e, "binding");
        napi_value r = js.get(e, "resource");
        std::string kind = js.fstr(r, "_kind");
        if (kind == "sampler") es[i].sampler = js.handle<WGPUSampler>(r);
        else if (kind == "view") es[i].textureView = js.handle<WGPUTextureView>(r);
        else if (kind == "texture") es[i].textureView = js.handle<WGPUTextureView>(js.get(r, "_defaultView"));
        else if (kind == "buffer") {
            es[i].buffer = js.handle<WGPUBuffer>(r);
            es[i].size = WGPU_WHOLE_SIZE;
        } else {
            // GPUBufferBinding {buffer, offset, size}
            es[i].buffer = js.handle<WGPUBuffer>(js.get(r, "buffer"));
            es[i].offset = js.fu64(r, "offset");
            es[i].size = js.fu64(r, "size", WGPU_WHOLE_SIZE);
        }
    }
    WGPUBindGroupDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.layout = js.handle<WGPUBindGroupLayout>(js.get(d, "layout"));
    desc.entryCount = n;
    desc.entries = es;
    return wrap<WGPUBindGroup, wgpuBindGroupRelease>(env, wgpuDeviceCreateBindGroup(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreateRenderPipeline(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPURenderPipelineDescriptor desc;
    fillRenderPipeline(js, a, args[1], desc);
    return wrap<WGPURenderPipeline, wgpuRenderPipelineRelease>(env, wgpuDeviceCreateRenderPipeline(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value CreateComputePipeline(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUComputePipelineDescriptor desc;
    fillComputePipeline(js, a, args[1], desc);
    return wrap<WGPUComputePipeline, wgpuComputePipelineRelease>(env, wgpuDeviceCreateComputePipeline(js.handle<WGPUDevice>(args[0]), &desc));
}

// pipelineGetBindGroupLayout(pipeline, index, isCompute)
static napi_value PipelineGetBindGroupLayout(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t idx = js.u32(args[1]);
    WGPUBindGroupLayout l = js.boolean(args[2]) ? wgpuComputePipelineGetBindGroupLayout(js.handle<WGPUComputePipeline>(args[0]), idx)
                                                : wgpuRenderPipelineGetBindGroupLayout(js.handle<WGPURenderPipeline>(args[0]), idx);
    return wrap<WGPUBindGroupLayout, wgpuBindGroupLayoutRelease>(env, l);
}

static napi_value CreateQuerySet(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPUQuerySetDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    desc.type = lookup(kQueryTypes, js.fstr(d, "type"), WGPUQueryType_Occlusion);
    desc.count = js.fu32(d, "count");
    return wrap<WGPUQuerySet, wgpuQuerySetRelease>(env, wgpuDeviceCreateQuerySet(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value QuerySetDestroy(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUQuerySet q = js.handle<WGPUQuerySet>(args[0]);
    if (q) wgpuQuerySetDestroy(q);
    return nullptr;
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// Command encoding
// ═════════════════════════════════════════════════════════════════════════════════════════════

static napi_value CreateCommandEncoder(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUCommandEncoderDescriptor desc = {};
    desc.label = sv(a, js.fstr(args[1], "label"));
    return wrap<WGPUCommandEncoder, wgpuCommandEncoderRelease>(env, wgpuDeviceCreateCommandEncoder(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value BeginRenderPass(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPURenderPassDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    napi_value cas = js.get(d, "colorAttachments");
    uint32_t n = js.length(cas);
    auto *cs = a.array<WGPURenderPassColorAttachment>(n);
    for (uint32_t i = 0; i < n; i++) {
        napi_value c = js.at(cas, i);
        cs[i].depthSlice = WGPU_DEPTH_SLICE_UNDEFINED;
        if (!c) continue;
        cs[i].view = js.handle<WGPUTextureView>(js.get(c, "view"));
        cs[i].resolveTarget = js.handle<WGPUTextureView>(js.get(c, "resolveTarget"));
        cs[i].depthSlice = js.fu32(c, "depthSlice", WGPU_DEPTH_SLICE_UNDEFINED);
        cs[i].loadOp = lookup(kLoadOps, js.fstr(c, "loadOp", "load"), WGPULoadOp_Load);
        cs[i].storeOp = lookup(kStoreOps, js.fstr(c, "storeOp", "store"), WGPUStoreOp_Store);
        cs[i].clearValue = color(js, js.get(c, "clearValue"));
    }
    desc.colorAttachmentCount = n;
    desc.colorAttachments = cs;
    if (napi_value ds = js.get(d, "depthStencilAttachment")) {
        auto *a2 = a.one<WGPURenderPassDepthStencilAttachment>();
        a2->view = js.handle<WGPUTextureView>(js.get(ds, "view"));
        a2->depthLoadOp = lookup(kLoadOps, js.fstr(ds, "depthLoadOp"), WGPULoadOp_Undefined);
        a2->depthStoreOp = lookup(kStoreOps, js.fstr(ds, "depthStoreOp"), WGPUStoreOp_Undefined);
        a2->depthClearValue = (float)js.fnum(ds, "depthClearValue", 0);
        a2->depthReadOnly = js.fbool(ds, "depthReadOnly");
        a2->stencilLoadOp = lookup(kLoadOps, js.fstr(ds, "stencilLoadOp"), WGPULoadOp_Undefined);
        a2->stencilStoreOp = lookup(kStoreOps, js.fstr(ds, "stencilStoreOp"), WGPUStoreOp_Undefined);
        a2->stencilClearValue = js.fu32(ds, "stencilClearValue");
        a2->stencilReadOnly = js.fbool(ds, "stencilReadOnly");
        desc.depthStencilAttachment = a2;
    }
    desc.occlusionQuerySet = js.handle<WGPUQuerySet>(js.get(d, "occlusionQuerySet"));
    desc.timestampWrites = timestampWrites(js, a, js.get(d, "timestampWrites"));
    return wrap<WGPURenderPassEncoder, wgpuRenderPassEncoderRelease>(
        env, wgpuCommandEncoderBeginRenderPass(js.handle<WGPUCommandEncoder>(args[0]), &desc));
}

static napi_value BeginComputePass(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUComputePassDescriptor desc = {};
    desc.label = sv(a, js.fstr(args[1], "label"));
    desc.timestampWrites = timestampWrites(js, a, js.get(args[1], "timestampWrites"));
    return wrap<WGPUComputePassEncoder, wgpuComputePassEncoderRelease>(
        env, wgpuCommandEncoderBeginComputePass(js.handle<WGPUCommandEncoder>(args[0]), &desc));
}

static napi_value CopyBufferToBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuCommandEncoderCopyBufferToBuffer(js.handle<WGPUCommandEncoder>(args[0]), js.handle<WGPUBuffer>(args[1]), js.u64(args[2]),
                                         js.handle<WGPUBuffer>(args[3]), js.u64(args[4]), js.u64(args[5], WGPU_WHOLE_SIZE));
    return nullptr;
}

static napi_value CopyBufferToTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUTexelCopyBufferInfo src = {};
    src.buffer = js.handle<WGPUBuffer>(js.get(args[1], "buffer"));
    src.layout = bufferLayout(js, args[1]);
    WGPUTexelCopyTextureInfo dst = copyTexture(js, args[2]);
    WGPUExtent3D size = extent(js, args[3]);
    wgpuCommandEncoderCopyBufferToTexture(js.handle<WGPUCommandEncoder>(args[0]), &src, &dst, &size);
    return nullptr;
}

static napi_value CopyTextureToBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUTexelCopyTextureInfo src = copyTexture(js, args[1]);
    WGPUTexelCopyBufferInfo dst = {};
    dst.buffer = js.handle<WGPUBuffer>(js.get(args[2], "buffer"));
    dst.layout = bufferLayout(js, args[2]);
    WGPUExtent3D size = extent(js, args[3]);
    wgpuCommandEncoderCopyTextureToBuffer(js.handle<WGPUCommandEncoder>(args[0]), &src, &dst, &size);
    return nullptr;
}

static napi_value CopyTextureToTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUTexelCopyTextureInfo src = copyTexture(js, args[1]);
    WGPUTexelCopyTextureInfo dst = copyTexture(js, args[2]);
    WGPUExtent3D size = extent(js, args[3]);
    wgpuCommandEncoderCopyTextureToTexture(js.handle<WGPUCommandEncoder>(args[0]), &src, &dst, &size);
    return nullptr;
}

static napi_value ClearBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuCommandEncoderClearBuffer(js.handle<WGPUCommandEncoder>(args[0]), js.handle<WGPUBuffer>(args[1]), js.u64(args[2]),
                                  js.u64(args[3], WGPU_WHOLE_SIZE));
    return nullptr;
}

static napi_value ResolveQuerySet(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuCommandEncoderResolveQuerySet(js.handle<WGPUCommandEncoder>(args[0]), js.handle<WGPUQuerySet>(args[1]), js.u32(args[2]),
                                      js.u32(args[3]), js.handle<WGPUBuffer>(args[4]), js.u64(args[5]));
    return nullptr;
}

static napi_value EncoderFinish(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPUCommandBufferDescriptor desc = {};
    desc.label = sv(a, js.fstr(args[1], "label"));
    return wrap<WGPUCommandBuffer, wgpuCommandBufferRelease>(env, wgpuCommandEncoderFinish(js.handle<WGPUCommandEncoder>(args[0]), &desc));
}

// Render pass / render bundle / compute pass commands. `kind` (first arg) picks the encoder type:
// 0 = render pass, 1 = render bundle encoder, 2 = compute pass.
enum PassKind { kRenderPass = 0, kBundle = 1, kCompute = 2 };

static void collectOffsets(Js &js, napi_value v, std::vector<uint32_t> &out) {
    uint32_t n = js.length(v);
    out.resize(n);
    for (uint32_t i = 0; i < n; i++) out[i] = js.u32(js.at(v, i));
}

static napi_value PassSetPipeline(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    switch (js.u32(args[0])) {
    case kRenderPass: wgpuRenderPassEncoderSetPipeline(js.handle<WGPURenderPassEncoder>(args[1]), js.handle<WGPURenderPipeline>(args[2])); break;
    case kBundle: wgpuRenderBundleEncoderSetPipeline(js.handle<WGPURenderBundleEncoder>(args[1]), js.handle<WGPURenderPipeline>(args[2])); break;
    case kCompute: wgpuComputePassEncoderSetPipeline(js.handle<WGPUComputePassEncoder>(args[1]), js.handle<WGPUComputePipeline>(args[2])); break;
    }
    return nullptr;
}

// passSetBindGroup(kind, pass, index, group, offsets?)
static napi_value PassSetBindGroup(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    std::vector<uint32_t> offsets;
    collectOffsets(js, args[4], offsets);
    uint32_t idx = js.u32(args[2]);
    WGPUBindGroup g = js.handle<WGPUBindGroup>(args[3]);
    switch (js.u32(args[0])) {
    case kRenderPass: wgpuRenderPassEncoderSetBindGroup(js.handle<WGPURenderPassEncoder>(args[1]), idx, g, offsets.size(), offsets.data()); break;
    case kBundle: wgpuRenderBundleEncoderSetBindGroup(js.handle<WGPURenderBundleEncoder>(args[1]), idx, g, offsets.size(), offsets.data()); break;
    case kCompute: wgpuComputePassEncoderSetBindGroup(js.handle<WGPUComputePassEncoder>(args[1]), idx, g, offsets.size(), offsets.data()); break;
    }
    return nullptr;
}

// passSetVertexBuffer(kind, pass, slot, buffer, offset, size)
static napi_value PassSetVertexBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t slot = js.u32(args[2]);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[3]);
    uint64_t off = js.u64(args[4]), size = js.u64(args[5], WGPU_WHOLE_SIZE);
    if (js.u32(args[0]) == kBundle) wgpuRenderBundleEncoderSetVertexBuffer(js.handle<WGPURenderBundleEncoder>(args[1]), slot, b, off, size);
    else wgpuRenderPassEncoderSetVertexBuffer(js.handle<WGPURenderPassEncoder>(args[1]), slot, b, off, size);
    return nullptr;
}

// passSetIndexBuffer(kind, pass, buffer, format, offset, size)
static napi_value PassSetIndexBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[2]);
    WGPUIndexFormat f = lookup(kIndexFormats, js.str(args[3]), WGPUIndexFormat_Uint16);
    uint64_t off = js.u64(args[4]), size = js.u64(args[5], WGPU_WHOLE_SIZE);
    if (js.u32(args[0]) == kBundle) wgpuRenderBundleEncoderSetIndexBuffer(js.handle<WGPURenderBundleEncoder>(args[1]), b, f, off, size);
    else wgpuRenderPassEncoderSetIndexBuffer(js.handle<WGPURenderPassEncoder>(args[1]), b, f, off, size);
    return nullptr;
}

// passDraw(kind, pass, vertexCount, instanceCount, firstVertex, firstInstance)
static napi_value PassDraw(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t vc = js.u32(args[2]), ic = js.u32(args[3], 1), fv = js.u32(args[4]), fi = js.u32(args[5]);
    if (js.u32(args[0]) == kBundle) wgpuRenderBundleEncoderDraw(js.handle<WGPURenderBundleEncoder>(args[1]), vc, ic, fv, fi);
    else wgpuRenderPassEncoderDraw(js.handle<WGPURenderPassEncoder>(args[1]), vc, ic, fv, fi);
    return nullptr;
}

// passDrawIndexed(kind, pass, indexCount, instanceCount, firstIndex, baseVertex, firstInstance)
static napi_value PassDrawIndexed(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t ic = js.u32(args[2]), inst = js.u32(args[3], 1), fi = js.u32(args[4]), fin = js.u32(args[6]);
    int32_t bv = js.i32(args[5]);
    if (js.u32(args[0]) == kBundle) wgpuRenderBundleEncoderDrawIndexed(js.handle<WGPURenderBundleEncoder>(args[1]), ic, inst, fi, bv, fin);
    else wgpuRenderPassEncoderDrawIndexed(js.handle<WGPURenderPassEncoder>(args[1]), ic, inst, fi, bv, fin);
    return nullptr;
}

// passDrawIndirect(kind, pass, buffer, offset, indexed)
static napi_value PassDrawIndirect(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUBuffer b = js.handle<WGPUBuffer>(args[2]);
    uint64_t off = js.u64(args[3]);
    bool indexed = js.boolean(args[4]);
    if (js.u32(args[0]) == kBundle) {
        auto p = js.handle<WGPURenderBundleEncoder>(args[1]);
        indexed ? wgpuRenderBundleEncoderDrawIndexedIndirect(p, b, off) : wgpuRenderBundleEncoderDrawIndirect(p, b, off);
    } else {
        auto p = js.handle<WGPURenderPassEncoder>(args[1]);
        indexed ? wgpuRenderPassEncoderDrawIndexedIndirect(p, b, off) : wgpuRenderPassEncoderDrawIndirect(p, b, off);
    }
    return nullptr;
}

static napi_value PassDispatch(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuComputePassEncoderDispatchWorkgroups(js.handle<WGPUComputePassEncoder>(args[0]), js.u32(args[1]), js.u32(args[2], 1), js.u32(args[3], 1));
    return nullptr;
}

static napi_value PassDispatchIndirect(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuComputePassEncoderDispatchWorkgroupsIndirect(js.handle<WGPUComputePassEncoder>(args[0]), js.handle<WGPUBuffer>(args[1]), js.u64(args[2]));
    return nullptr;
}

static napi_value PassSetViewport(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuRenderPassEncoderSetViewport(js.handle<WGPURenderPassEncoder>(args[0]), (float)js.num(args[1]), (float)js.num(args[2]),
                                     (float)js.num(args[3]), (float)js.num(args[4]), (float)js.num(args[5]), (float)js.num(args[6], 1));
    return nullptr;
}

static napi_value PassSetScissorRect(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuRenderPassEncoderSetScissorRect(js.handle<WGPURenderPassEncoder>(args[0]), js.u32(args[1]), js.u32(args[2]), js.u32(args[3]), js.u32(args[4]));
    return nullptr;
}

static napi_value PassSetBlendConstant(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    WGPUColor c = color(js, args[1]);
    wgpuRenderPassEncoderSetBlendConstant(js.handle<WGPURenderPassEncoder>(args[0]), &c);
    return nullptr;
}

static napi_value PassSetStencilReference(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    wgpuRenderPassEncoderSetStencilReference(js.handle<WGPURenderPassEncoder>(args[0]), js.u32(args[1]));
    return nullptr;
}

static napi_value PassOcclusionQuery(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    auto p = js.handle<WGPURenderPassEncoder>(args[0]);
    if (args[1]) wgpuRenderPassEncoderBeginOcclusionQuery(p, js.u32(args[1]));
    else wgpuRenderPassEncoderEndOcclusionQuery(p);
    return nullptr;
}

static napi_value PassExecuteBundles(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t n = js.length(args[1]);
    std::vector<WGPURenderBundle> bundles(n);
    for (uint32_t i = 0; i < n; i++) bundles[i] = js.handle<WGPURenderBundle>(js.at(args[1], i));
    wgpuRenderPassEncoderExecuteBundles(js.handle<WGPURenderPassEncoder>(args[0]), n, bundles.data());
    return nullptr;
}

static napi_value PassEnd(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    if (js.u32(args[0]) == kCompute) wgpuComputePassEncoderEnd(js.handle<WGPUComputePassEncoder>(args[1]));
    else wgpuRenderPassEncoderEnd(js.handle<WGPURenderPassEncoder>(args[1]));
    return nullptr;
}

static napi_value CreateRenderBundleEncoder(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    napi_value d = args[1];
    WGPURenderBundleEncoderDescriptor desc = {};
    desc.label = sv(a, js.fstr(d, "label"));
    napi_value cf = js.get(d, "colorFormats");
    uint32_t n = js.length(cf);
    auto *fs = a.array<WGPUTextureFormat>(n);
    for (uint32_t i = 0; i < n; i++) fs[i] = textureFormat(js.str(js.at(cf, i)));
    desc.colorFormatCount = n;
    desc.colorFormats = fs;
    desc.depthStencilFormat = textureFormat(js.fstr(d, "depthStencilFormat"));
    desc.sampleCount = js.fu32(d, "sampleCount", 1);
    desc.depthReadOnly = js.fbool(d, "depthReadOnly");
    desc.stencilReadOnly = js.fbool(d, "stencilReadOnly");
    return wrap<WGPURenderBundleEncoder, wgpuRenderBundleEncoderRelease>(
        env, wgpuDeviceCreateRenderBundleEncoder(js.handle<WGPUDevice>(args[0]), &desc));
}

static napi_value RenderBundleFinish(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    WGPURenderBundleDescriptor desc = {};
    desc.label = sv(a, js.fstr(args[1], "label"));
    return wrap<WGPURenderBundle, wgpuRenderBundleRelease>(env, wgpuRenderBundleEncoderFinish(js.handle<WGPURenderBundleEncoder>(args[0]), &desc));
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// Queue
// ═════════════════════════════════════════════════════════════════════════════════════════════

static napi_value QueueSubmit(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint32_t n = js.length(args[1]);
    std::vector<WGPUCommandBuffer> cbs;
    for (uint32_t i = 0; i < n; i++) {
        WGPUCommandBuffer c = js.handle<WGPUCommandBuffer>(js.at(args[1], i));
        if (c) cbs.push_back(c);
    }
    wgpuQueueSubmit(js.handle<WGPUQueue>(args[0]), cbs.size(), cbs.data());
    return nullptr;
}

// queueWriteBuffer(queue, buffer, bufferOffset, data, dataOffsetBytes, sizeBytes)
static napi_value QueueWriteBuffer(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint8_t *data; size_t len;
    if (!js.bytes(args[3], data, len)) { js.throwError("writeBuffer: data must be an ArrayBuffer or view"); return nullptr; }
    size_t off = (size_t)js.u64(args[4]);
    size_t size = args[5] ? (size_t)js.u64(args[5]) : (len - off);
    if (off + size > len) { js.throwError("writeBuffer: range out of bounds"); return nullptr; }
    wgpuQueueWriteBuffer(js.handle<WGPUQueue>(args[0]), js.handle<WGPUBuffer>(args[1]), js.u64(args[2]), data + off, size);
    return nullptr;
}

// queueWriteTexture(queue, destination, data, dataLayout, size)
static napi_value QueueWriteTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint8_t *data; size_t len;
    if (!js.bytes(args[2], data, len)) { js.throwError("writeTexture: data must be an ArrayBuffer or view"); return nullptr; }
    WGPUTexelCopyTextureInfo dst = copyTexture(js, args[1]);
    WGPUTexelCopyBufferLayout layout = bufferLayout(js, args[3]);
    WGPUExtent3D size = extent(js, args[4]);
    wgpuQueueWriteTexture(js.handle<WGPUQueue>(args[0]), &dst, data, len, &layout, &size);
    return nullptr;
}

static napi_value QueueOnSubmittedWorkDone(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    napi_value promise;
    Pending *p = newPending(env, &promise);
    WGPUQueueWorkDoneCallbackInfo cb = {};
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = [](WGPUQueueWorkDoneStatus, WGPUStringView, void *u1, void *) {
        auto *p = (Pending *)u1;
        Js js(p->env);
        settle(p, true, js.undefined());
    };
    cb.userdata1 = p;
    wgpuQueueOnSubmittedWorkDone(js.handle<WGPUQueue>(args[0]), cb);
    return promise;
}

// Half-float conversion for rgba16float uploads.
static uint16_t toHalf(float f) {
    uint32_t x;
    memcpy(&x, &f, 4);
    uint32_t sign = (x >> 16) & 0x8000;
    int32_t exp = ((x >> 23) & 0xFF) - 127 + 15;
    uint32_t mant = x & 0x7FFFFF;
    if (exp <= 0) return (uint16_t)sign;
    if (exp >= 31) return (uint16_t)(sign | 0x7C00);
    return (uint16_t)(sign | (exp << 10) | (mant >> 13));
}

// copyRGBA8ToTexture(queue, pixels, srcWidth, srcHeight, srcOriginX, srcOriginY, destination, copyWidth, copyHeight,
//                    flipY, premultiply, destFormat)
// The CPU side of copyExternalImageToTexture: pixels are straight-alpha RGBA8 rows.
static napi_value CopyRGBA8ToTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    uint8_t *px; size_t len;
    if (!js.bytes(args[1], px, len)) return nullptr;
    uint32_t sw = js.u32(args[2]), sh = js.u32(args[3]), ox = js.u32(args[4]), oy = js.u32(args[5]);
    WGPUTexelCopyTextureInfo dst = copyTexture(js, args[6]);
    uint32_t w = js.u32(args[7]), h = js.u32(args[8]);
    bool flipY = js.boolean(args[9]), premul = js.boolean(args[10]);
    WGPUTextureFormat fmt = textureFormat(js.str(args[11]));
    if (w == 0 || h == 0 || (size_t)sw * sh * 4 > len) return nullptr;
    int bpp = (fmt == WGPUTextureFormat_RGBA16Float) ? 8 : (fmt == WGPUTextureFormat_RGBA32Float) ? 16 : 4;
    std::vector<uint8_t> out((size_t)w * h * bpp);
    for (uint32_t y = 0; y < h; y++) {
        uint32_t sy = flipY ? (oy + h - 1 - y) : (oy + y);
        if (sy >= sh) continue;
        const uint8_t *row = px + ((size_t)sy * sw + ox) * 4;
        uint8_t *orow = out.data() + (size_t)y * w * bpp;
        for (uint32_t x = 0; x < w && ox + x < sw; x++) {
            uint8_t r = row[x * 4], g = row[x * 4 + 1], b = row[x * 4 + 2], a = row[x * 4 + 3];
            if (premul && a != 255) { r = (uint8_t)((r * a + 127) / 255); g = (uint8_t)((g * a + 127) / 255); b = (uint8_t)((b * a + 127) / 255); }
            switch (fmt) {
            case WGPUTextureFormat_BGRA8Unorm:
            case WGPUTextureFormat_BGRA8UnormSrgb:
                orow[x * 4] = b; orow[x * 4 + 1] = g; orow[x * 4 + 2] = r; orow[x * 4 + 3] = a;
                break;
            case WGPUTextureFormat_RGBA16Float: {
                uint16_t *o = (uint16_t *)(orow + x * 8);
                o[0] = toHalf(r / 255.f); o[1] = toHalf(g / 255.f); o[2] = toHalf(b / 255.f); o[3] = toHalf(a / 255.f);
                break;
            }
            case WGPUTextureFormat_RGBA32Float: {
                float *o = (float *)(orow + x * 16);
                o[0] = r / 255.f; o[1] = g / 255.f; o[2] = b / 255.f; o[3] = a / 255.f;
                break;
            }
            default:
                orow[x * 4] = r; orow[x * 4 + 1] = g; orow[x * 4 + 2] = b; orow[x * 4 + 3] = a;
            }
        }
    }
    WGPUTexelCopyBufferLayout layout = {0, w * (uint32_t)bpp, h};
    WGPUExtent3D size = {w, h, 1};
    wgpuQueueWriteTexture(js.handle<WGPUQueue>(args[0]), &dst, out.data(), out.size(), &layout, &size);
    return nullptr;
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// Surface (XComponent → OHNativeWindow → VkSurface)
// ═════════════════════════════════════════════════════════════════════════════════════════════

// Drops the swapchain, the VkSurface and the native window right away. Must happen before the
// XComponent hands out a new surface for the same window: a second VkSurface on a window that
// still has a swapchain fails with VK_ERROR_NATIVE_WINDOW_IN_USE_KHR.
static void destroySurface(SurfaceRec *s) {
    if (s->current) { wgpuTextureRelease(s->current); s->current = nullptr; }
    if (s->surface) { wgpuSurfaceRelease(s->surface); s->surface = nullptr; }
    if (s->window) { OH_NativeWindow_DestroyNativeWindow(s->window); s->window = nullptr; }
}

static void releaseSurface(SurfaceRec *s) {
    destroySurface(s);
    delete s;
}

// createSurface(surfaceId: string) -> external | null
static napi_value CreateSurface(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    std::string idStr = js.str(args[0]);
    uint64_t id = strtoull(idStr.c_str(), nullptr, 10);
    OHNativeWindow *win = nullptr;
    int32_t rc = OH_NativeWindow_CreateNativeWindowFromSurfaceId(id, &win);
    if (rc != 0 || !win) {
        OH_LOG_ERROR(LOG_APP, "CreateNativeWindowFromSurfaceId(%{public}s) failed: %{public}d", idStr.c_str(), rc);
        return js.null();
    }
    WGPUSurfaceSourceOhosNativeWindow src = {};
    src.chain.sType = (WGPUSType)WGPUSType_SurfaceSourceOhosNativeWindow;
    src.window = win;
    WGPUSurfaceDescriptor desc = {};
    desc.nextInChain = &src.chain;
    WGPUSurface surface = wgpuInstanceCreateSurface(instance(), &desc);
    if (!surface) {
        OH_NativeWindow_DestroyNativeWindow(win);
        return js.null();
    }
    auto *rec = new SurfaceRec{surface, win, nullptr, false};
    napi_value v;
    napi_create_external(env, rec, [](napi_env, void *d, void *) { releaseSurface((SurfaceRec *)d); }, nullptr, &v);
    return v;
}

static SurfaceRec *surfaceOf(Js &js, napi_value v) {
    SurfaceRec *s = js.handle<SurfaceRec *>(v);
    return s && s->surface ? s : nullptr;
}

static napi_value SurfaceDestroy(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    SurfaceRec *s = js.handle<SurfaceRec *>(args[0]);
    if (s) destroySurface(s);
    return nullptr;
}

// surfaceCapabilities(surface, adapter) -> {formats:[], alphaModes:[], usages}
static napi_value SurfaceCapabilities(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    SurfaceRec *s = surfaceOf(js, args[0]);
    napi_value o = js.mkObj();
    if (!s) return o;
    WGPUSurfaceCapabilities caps = {};
    wgpuSurfaceGetCapabilities(s->surface, js.handle<WGPUAdapter>(args[1]), &caps);
    napi_value formats = js.mkArr();
    for (size_t i = 0; i < caps.formatCount; i++) {
        const char *n = nameOf(kTextureFormats, caps.formats[i]);
        if (n) js.push(formats, js.mkStr(n));
    }
    napi_value alpha = js.mkArr();
    for (size_t i = 0; i < caps.alphaModeCount; i++) {
        const char *n = nameOf(kAlphaModes, caps.alphaModes[i]);
        if (n) js.push(alpha, js.mkStr(n));
    }
    js.set(o, "formats", formats);
    js.set(o, "alphaModes", alpha);
    js.set(o, "usages", js.mkNum((double)caps.usages));
    wgpuSurfaceCapabilitiesFreeMembers(caps);
    return o;
}

// surfaceConfigure(surface, device, {format, usage, width, height, alphaMode, viewFormats})
static napi_value SurfaceConfigure(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    Arena a;
    SurfaceRec *s = surfaceOf(js, args[0]);
    if (!s) return nullptr;
    napi_value d = args[2];
    WGPUSurfaceConfiguration cfg = {};
    cfg.device = js.handle<WGPUDevice>(args[1]);
    cfg.format = textureFormat(js.fstr(d, "format"));
    cfg.usage = js.fu64(d, "usage", WGPUTextureUsage_RenderAttachment);
    cfg.width = js.fu32(d, "width", 1);
    cfg.height = js.fu32(d, "height", 1);
    napi_value vf = js.get(d, "viewFormats");
    uint32_t n = js.length(vf);
    auto *fs = a.array<WGPUTextureFormat>(n);
    for (uint32_t i = 0; i < n; i++) fs[i] = textureFormat(js.str(js.at(vf, i)));
    cfg.viewFormatCount = n;
    cfg.viewFormats = fs;
    cfg.alphaMode = lookup(kAlphaModes, js.fstr(d, "alphaMode", "opaque"), WGPUCompositeAlphaMode_Auto);
    cfg.presentMode = WGPUPresentMode_Fifo;
    if (s->current) { wgpuTextureRelease(s->current); s->current = nullptr; }
    // Drop the old swapchain before creating the new one: some drivers (the OpenHarmony emulator's
    // Vulkan translation) reject a swapchain recreated through oldSwapchain with
    // VK_ERROR_NATIVE_WINDOW_IN_USE_KHR.
    if (s->configured) wgpuSurfaceUnconfigure(s->surface);
    wgpuSurfaceConfigure(s->surface, &cfg);
    s->configured = true;
    return nullptr;
}

static napi_value SurfaceUnconfigure(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    SurfaceRec *s = surfaceOf(js, args[0]);
    if (!s) return nullptr;
    if (s->current) { wgpuTextureRelease(s->current); s->current = nullptr; }
    if (s->configured) wgpuSurfaceUnconfigure(s->surface);
    s->configured = false;
    return nullptr;
}

// surfaceGetCurrentTexture(surface) -> {texture: external|null, status}
// The surface keeps its own reference to the frame texture and drops it after present.
static napi_value SurfaceGetCurrentTexture(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    SurfaceRec *s = surfaceOf(js, args[0]);
    napi_value o = js.mkObj();
    if (!s) return o;
    if (!s->current) {
        WGPUSurfaceTexture st = {};
        wgpuSurfaceGetCurrentTexture(s->surface, &st);
        js.set(o, "status", js.mkNum(st.status));
        if (st.status != WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal &&
            st.status != WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal) {
            if (st.texture) wgpuTextureRelease(st.texture);
            js.set(o, "texture", js.null());
            return o;
        }
        s->current = st.texture;
    }
    // Non-owning handle: the surface record holds the only reference and drops it on present /
    // reconfigure / destroy. A JS-owned reference would be released by the GC at an arbitrary
    // later time — after the surface itself may be gone — and wgpu aborts on that.
    napi_value tex;
    napi_create_external(env, (void *)s->current, nullptr, nullptr, &tex);
    js.set(o, "texture", tex);
    return o;
}

static napi_value SurfacePresent(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    SurfaceRec *s = surfaceOf(js, args[0]);
    if (!s || !s->current) return js.mkBool(false);
    WGPUStatus st = wgpuSurfacePresent(s->surface);
    wgpuTextureRelease(s->current);
    s->current = nullptr;
    return js.mkBool(st == WGPUStatus_Success);
}


// ═════════════════════════════════════════════════════════════════════════════════════════════
// Video frames (AVPlayer / camera → consumer surface → textures)
// ═════════════════════════════════════════════════════════════════════════════════════════════

struct VideoRec {
    OH_NativeImage *image = nullptr;
    OHNativeWindowBuffer *held = nullptr;  // latest acquired frame, released on the next acquire
    int heldFence = -1;
};

static void releaseHeld(VideoRec *v) {
    if (v->held) {
        OH_NativeImage_ReleaseNativeWindowBuffer(v->image, v->held, v->heldFence);
        v->held = nullptr;
        v->heldFence = -1;
    }
}

// videoSurfaceCreate() -> {handle, surfaceId}
static napi_value VideoSurfaceCreate(napi_env env, napi_callback_info) {
    Js js(env);
    OH_NativeImage *img = OH_ConsumerSurface_Create();
    if (!img) return js.null();
    OH_ConsumerSurface_SetDefaultUsage(img, NATIVEBUFFER_USAGE_CPU_READ | NATIVEBUFFER_USAGE_MEM_DMA);
    uint64_t sid = 0;
    OH_NativeImage_GetSurfaceId(img, &sid);
    auto *rec = new VideoRec{img};
    napi_value h;
    napi_create_external(env, rec, [](napi_env, void *d, void *) {
        auto *v = (VideoRec *)d;
        releaseHeld(v);
        if (v->image) OH_NativeImage_Destroy(&v->image);
        delete v;
    }, nullptr, &h);
    napi_value o = js.mkObj();
    js.set(o, "handle", h);
    js.set(o, "surfaceId", js.mkStr(std::to_string(sid)));
    return o;
}

static const char *videoFormatName(int32_t f) {
    switch (f) {
    case NATIVEBUFFER_PIXEL_FMT_YCBCR_420_SP: return "nv12";
    case NATIVEBUFFER_PIXEL_FMT_YCRCB_420_SP: return "nv21";
    case NATIVEBUFFER_PIXEL_FMT_RGBA_8888:
    case NATIVEBUFFER_PIXEL_FMT_RGBX_8888: return "rgba";
    case NATIVEBUFFER_PIXEL_FMT_BGRA_8888:
    case NATIVEBUFFER_PIXEL_FMT_BGRX_8888: return "bgra";
    default: return nullptr;
    }
}

// videoAcquire(handle) -> {width, height, format} for a new frame, or null when nothing new arrived.
// Drains the queue so only the newest frame is kept.
static napi_value VideoAcquire(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    auto *v = js.handle<VideoRec *>(args[0]);
    if (!v || !v->image) return js.null();
    bool any = false;
    for (int i = 0; i < 8; i++) {
        OHNativeWindowBuffer *buf = nullptr;
        int fence = -1;
        if (OH_NativeImage_AcquireNativeWindowBuffer(v->image, &buf, &fence) != 0 || !buf) break;
        releaseHeld(v);
        v->held = buf;
        v->heldFence = fence;
        any = true;
    }
    if (!any || !v->held) return js.null();
    OH_NativeBuffer *nb = nullptr;
    OH_NativeBuffer_FromNativeWindowBuffer(v->held, &nb);
    if (!nb) return js.null();
    OH_NativeBuffer_Config cfg = {};
    OH_NativeBuffer_GetConfig(nb, &cfg);
    const char *fmt = videoFormatName(cfg.format);
    napi_value o = js.mkObj();
    js.set(o, "width", js.mkNum(cfg.width));
    js.set(o, "height", js.mkNum(cfg.height));
    js.set(o, "format", fmt ? js.mkStr(fmt) : js.mkStr("unsupported:" + std::to_string(cfg.format)));
    return o;
}

// videoUpload(handle, queue, plane0Texture, plane1Texture?) — copies the held frame's planes.
// RGBA/BGRA frames use plane 0 only; NV12/NV21 write Y to plane 0 (r8) and CbCr to plane 1 (rg8).
static napi_value VideoUpload(napi_env env, napi_callback_info info) {
    Args args(env, info);
    Js js(env);
    auto *v = js.handle<VideoRec *>(args[0]);
    WGPUQueue queue = js.handle<WGPUQueue>(args[1]);
    WGPUTexture t0 = js.handle<WGPUTexture>(args[2]);
    WGPUTexture t1 = js.handle<WGPUTexture>(args[3]);
    if (!v || !v->held || !queue || !t0) return js.mkBool(false);
    OH_NativeBuffer *nb = nullptr;
    OH_NativeBuffer_FromNativeWindowBuffer(v->held, &nb);
    if (!nb) return js.mkBool(false);
    if (v->heldFence >= 0) {
        // Wait for the producer to finish writing (decoders signal through the fence).
        fd_set set;
        FD_ZERO(&set);
        FD_SET(v->heldFence, &set);
        timeval tv{0, 50000};
        select(v->heldFence + 1, &set, nullptr, nullptr, &tv);
    }
    OH_NativeBuffer_Config cfg = {};
    OH_NativeBuffer_GetConfig(nb, &cfg);
    void *addr = nullptr;
    OH_NativeBuffer_Planes planes = {};
    bool mapped = OH_NativeBuffer_MapPlanes(nb, &addr, &planes) == 0 && addr;
    if (!mapped) {
        if (OH_NativeBuffer_Map(nb, &addr) != 0 || !addr) return js.mkBool(false);
        planes.planeCount = 0;
    }
    const uint8_t *base = (const uint8_t *)addr;
    uint32_t w = (uint32_t)cfg.width, h = (uint32_t)cfg.height;
    // Some devices swap the two stride fields (LAP-AL10 reports the row pitch as columnStride),
    // so take the larger one as the pitch: a pitch is always at least the pixel step.
    auto pitch = [&](uint32_t i) {
        return std::max(planes.planes[i].rowStride, planes.planes[i].columnStride);
    };
    WGPUTexelCopyTextureInfo dst = {};
    dst.aspect = WGPUTextureAspect_All;
    const char *fmt = videoFormatName(cfg.format);
    bool ok = fmt != nullptr;
    if (ok && (fmt[0] == 'r' || fmt[0] == 'b')) {
        uint32_t stride = planes.planeCount > 0 ? pitch(0) : (uint32_t)cfg.stride;
        dst.texture = t0;
        WGPUTexelCopyBufferLayout layout = {planes.planeCount > 0 ? planes.planes[0].offset : 0, stride, h};
        WGPUExtent3D size = {w, h, 1};
        wgpuQueueWriteTexture(queue, &dst, base, (size_t)layout.offset + (size_t)stride * h, &layout, &size);
    } else if (ok && t1) {
        // Semi-planar 4:2:0. Without plane info assume the common layout: UV right after Y.
        uint32_t yStride = planes.planeCount > 0 ? pitch(0) : (uint32_t)cfg.stride;
        uint64_t yOff = planes.planeCount > 0 ? planes.planes[0].offset : 0;
        uint64_t uvOff = planes.planeCount > 1 ? planes.planes[1].offset : yOff + (uint64_t)yStride * h;
        uint32_t uvStride = planes.planeCount > 1 ? pitch(1) : yStride;
        // For NV21 MapPlanes may report the V plane first; the interleaved block starts at the lower offset.
        if (planes.planeCount > 2) uvOff = std::min(planes.planes[1].offset, planes.planes[2].offset);
        dst.texture = t0;
        WGPUTexelCopyBufferLayout ly = {yOff, yStride, h};
        WGPUExtent3D ys = {w, h, 1};
        wgpuQueueWriteTexture(queue, &dst, base, (size_t)yOff + (size_t)yStride * h, &ly, &ys);
        dst.texture = t1;
        WGPUTexelCopyBufferLayout luv = {uvOff, uvStride, h / 2};
        WGPUExtent3D uvs = {w / 2, h / 2, 1};
        wgpuQueueWriteTexture(queue, &dst, base, (size_t)uvOff + (size_t)uvStride * (h / 2), &luv, &uvs);
    }
    OH_NativeBuffer_Unmap(nb);
    return js.mkBool(ok);
}

// Monotonic milliseconds for performance.now().
static napi_value Now(napi_env env, napi_callback_info) {
    timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    napi_value v;
    napi_create_double(env, ts.tv_sec * 1e3 + ts.tv_nsec / 1e6, &v);
    return v;
}

// ═════════════════════════════════════════════════════════════════════════════════════════════

#define FN(name, fn) {name, nullptr, fn, nullptr, nullptr, nullptr, napi_default, nullptr}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        FN("now", Now),
        FN("requestAdapter", RequestAdapter),
        FN("adapterInfo", AdapterInfo),
        FN("adapterLimits", AdapterLimits),
        FN("adapterFeatures", AdapterFeatures),
        FN("requestDevice", RequestDevice),
        FN("deviceLimits", DeviceLimits),
        FN("deviceFeatures", DeviceFeatures),
        FN("deviceQueue", DeviceQueue),
        FN("deviceDestroy", DeviceDestroy),
        FN("takeEvents", TakeEvents),
        FN("poll", Poll),
        FN("pushErrorScope", PushErrorScope),
        FN("popErrorScope", PopErrorScope),
        FN("createBuffer", CreateBuffer),
        FN("bufferDestroy", BufferDestroy),
        FN("bufferMapAsync", BufferMapAsync),
        FN("bufferReadMapped", BufferReadMapped),
        FN("bufferWriteMapped", BufferWriteMapped),
        FN("bufferUnmap", BufferUnmap),
        FN("createTexture", CreateTexture),
        FN("textureDestroy", TextureDestroy),
        FN("createView", CreateView),
        FN("createSampler", CreateSampler),
        FN("createShaderModule", CreateShaderModule),
        FN("createBindGroupLayout", CreateBindGroupLayout),
        FN("createPipelineLayout", CreatePipelineLayout),
        FN("createBindGroup", CreateBindGroup),
        FN("createRenderPipeline", CreateRenderPipeline),
        FN("createComputePipeline", CreateComputePipeline),
        FN("pipelineGetBindGroupLayout", PipelineGetBindGroupLayout),
        FN("createQuerySet", CreateQuerySet),
        FN("querySetDestroy", QuerySetDestroy),
        FN("createCommandEncoder", CreateCommandEncoder),
        FN("beginRenderPass", BeginRenderPass),
        FN("beginComputePass", BeginComputePass),
        FN("copyBufferToBuffer", CopyBufferToBuffer),
        FN("copyBufferToTexture", CopyBufferToTexture),
        FN("copyTextureToBuffer", CopyTextureToBuffer),
        FN("copyTextureToTexture", CopyTextureToTexture),
        FN("clearBuffer", ClearBuffer),
        FN("resolveQuerySet", ResolveQuerySet),
        FN("encoderFinish", EncoderFinish),
        FN("passSetPipeline", PassSetPipeline),
        FN("passSetBindGroup", PassSetBindGroup),
        FN("passSetVertexBuffer", PassSetVertexBuffer),
        FN("passSetIndexBuffer", PassSetIndexBuffer),
        FN("passDraw", PassDraw),
        FN("passDrawIndexed", PassDrawIndexed),
        FN("passDrawIndirect", PassDrawIndirect),
        FN("passDispatch", PassDispatch),
        FN("passDispatchIndirect", PassDispatchIndirect),
        FN("passSetViewport", PassSetViewport),
        FN("passSetScissorRect", PassSetScissorRect),
        FN("passSetBlendConstant", PassSetBlendConstant),
        FN("passSetStencilReference", PassSetStencilReference),
        FN("passOcclusionQuery", PassOcclusionQuery),
        FN("passExecuteBundles", PassExecuteBundles),
        FN("passEnd", PassEnd),
        FN("createRenderBundleEncoder", CreateRenderBundleEncoder),
        FN("renderBundleFinish", RenderBundleFinish),
        FN("queueSubmit", QueueSubmit),
        FN("queueWriteBuffer", QueueWriteBuffer),
        FN("queueWriteTexture", QueueWriteTexture),
        FN("queueOnSubmittedWorkDone", QueueOnSubmittedWorkDone),
        FN("copyRGBA8ToTexture", CopyRGBA8ToTexture),
        FN("createSurface", CreateSurface),
        FN("surfaceCapabilities", SurfaceCapabilities),
        FN("surfaceConfigure", SurfaceConfigure),
        FN("surfaceUnconfigure", SurfaceUnconfigure),
        FN("surfaceGetCurrentTexture", SurfaceGetCurrentTexture),
        FN("surfacePresent", SurfacePresent),
        FN("surfaceDestroy", SurfaceDestroy),
        FN("videoSurfaceCreate", VideoSurfaceCreate),
        FN("videoAcquire", VideoAcquire),
        FN("videoUpload", VideoUpload),
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module gModule = {1, 0, nullptr, Init, "webgpu_effects", nullptr, {0}};
extern "C" __attribute__((constructor)) void RegisterShadersGpu() { napi_module_register(&gModule); }
