// WebGPU IDL string enums <-> webgpu.h values.
#pragma once
#include "webgpu.h"
#include <cstring>
#include <string>

namespace sg {

template <typename E> struct Entry { const char *name; E value; };

template <typename E, size_t N> E lookup(const Entry<E> (&table)[N], const std::string &s, E def) {
    for (auto &e : table) if (s == e.name) return e.value;
    return def;
}
template <typename E, size_t N> const char *nameOf(const Entry<E> (&table)[N], E v) {
    for (auto &e : table) if (e.value == v) return e.name;
    return nullptr;
}

static const Entry<WGPUTextureFormat> kTextureFormats[] = {
    {"r8unorm", WGPUTextureFormat_R8Unorm}, {"r8snorm", WGPUTextureFormat_R8Snorm},
    {"r8uint", WGPUTextureFormat_R8Uint}, {"r8sint", WGPUTextureFormat_R8Sint},
    {"r16unorm", WGPUTextureFormat_R16Unorm}, {"r16snorm", WGPUTextureFormat_R16Snorm},
    {"r16uint", WGPUTextureFormat_R16Uint}, {"r16sint", WGPUTextureFormat_R16Sint},
    {"r16float", WGPUTextureFormat_R16Float}, {"rg8unorm", WGPUTextureFormat_RG8Unorm},
    {"rg8snorm", WGPUTextureFormat_RG8Snorm}, {"rg8uint", WGPUTextureFormat_RG8Uint},
    {"rg8sint", WGPUTextureFormat_RG8Sint}, {"r32float", WGPUTextureFormat_R32Float},
    {"r32uint", WGPUTextureFormat_R32Uint}, {"r32sint", WGPUTextureFormat_R32Sint},
    {"rg16unorm", WGPUTextureFormat_RG16Unorm}, {"rg16snorm", WGPUTextureFormat_RG16Snorm},
    {"rg16uint", WGPUTextureFormat_RG16Uint}, {"rg16sint", WGPUTextureFormat_RG16Sint},
    {"rg16float", WGPUTextureFormat_RG16Float}, {"rgba8unorm", WGPUTextureFormat_RGBA8Unorm},
    {"rgba8unorm-srgb", WGPUTextureFormat_RGBA8UnormSrgb}, {"rgba8snorm", WGPUTextureFormat_RGBA8Snorm},
    {"rgba8uint", WGPUTextureFormat_RGBA8Uint}, {"rgba8sint", WGPUTextureFormat_RGBA8Sint},
    {"bgra8unorm", WGPUTextureFormat_BGRA8Unorm}, {"bgra8unorm-srgb", WGPUTextureFormat_BGRA8UnormSrgb},
    {"rgb10a2uint", WGPUTextureFormat_RGB10A2Uint}, {"rgb10a2unorm", WGPUTextureFormat_RGB10A2Unorm},
    {"rg11b10ufloat", WGPUTextureFormat_RG11B10Ufloat}, {"rgb9e5ufloat", WGPUTextureFormat_RGB9E5Ufloat},
    {"rg32float", WGPUTextureFormat_RG32Float}, {"rg32uint", WGPUTextureFormat_RG32Uint},
    {"rg32sint", WGPUTextureFormat_RG32Sint}, {"rgba16unorm", WGPUTextureFormat_RGBA16Unorm},
    {"rgba16snorm", WGPUTextureFormat_RGBA16Snorm}, {"rgba16uint", WGPUTextureFormat_RGBA16Uint},
    {"rgba16sint", WGPUTextureFormat_RGBA16Sint}, {"rgba16float", WGPUTextureFormat_RGBA16Float},
    {"rgba32float", WGPUTextureFormat_RGBA32Float}, {"rgba32uint", WGPUTextureFormat_RGBA32Uint},
    {"rgba32sint", WGPUTextureFormat_RGBA32Sint}, {"stencil8", WGPUTextureFormat_Stencil8},
    {"depth16unorm", WGPUTextureFormat_Depth16Unorm}, {"depth24plus", WGPUTextureFormat_Depth24Plus},
    {"depth24plus-stencil8", WGPUTextureFormat_Depth24PlusStencil8}, {"depth32float", WGPUTextureFormat_Depth32Float},
    {"depth32float-stencil8", WGPUTextureFormat_Depth32FloatStencil8},
    {"bc1-rgba-unorm", WGPUTextureFormat_BC1RGBAUnorm}, {"bc1-rgba-unorm-srgb", WGPUTextureFormat_BC1RGBAUnormSrgb},
    {"bc3-rgba-unorm", WGPUTextureFormat_BC3RGBAUnorm}, {"bc7-rgba-unorm", WGPUTextureFormat_BC7RGBAUnorm},
    {"etc2-rgb8unorm", WGPUTextureFormat_ETC2RGB8Unorm}, {"etc2-rgba8unorm", WGPUTextureFormat_ETC2RGBA8Unorm},
    {"astc-4x4-unorm", WGPUTextureFormat_ASTC4x4Unorm}, {"astc-4x4-unorm-srgb", WGPUTextureFormat_ASTC4x4UnormSrgb},
};

static const Entry<WGPUFeatureName> kFeatures[] = {
    {"core-features-and-limits", WGPUFeatureName_CoreFeaturesAndLimits},
    {"depth-clip-control", WGPUFeatureName_DepthClipControl},
    {"depth32float-stencil8", WGPUFeatureName_Depth32FloatStencil8},
    {"texture-compression-bc", WGPUFeatureName_TextureCompressionBC},
    {"texture-compression-bc-sliced-3d", WGPUFeatureName_TextureCompressionBCSliced3D},
    {"texture-compression-etc2", WGPUFeatureName_TextureCompressionETC2},
    {"texture-compression-astc", WGPUFeatureName_TextureCompressionASTC},
    {"texture-compression-astc-sliced-3d", WGPUFeatureName_TextureCompressionASTCSliced3D},
    {"timestamp-query", WGPUFeatureName_TimestampQuery},
    {"indirect-first-instance", WGPUFeatureName_IndirectFirstInstance},
    {"shader-f16", WGPUFeatureName_ShaderF16},
    {"rg11b10ufloat-renderable", WGPUFeatureName_RG11B10UfloatRenderable},
    {"bgra8unorm-storage", WGPUFeatureName_BGRA8UnormStorage},
    {"float32-filterable", WGPUFeatureName_Float32Filterable},
    {"float32-blendable", WGPUFeatureName_Float32Blendable},
    {"clip-distances", WGPUFeatureName_ClipDistances},
    {"dual-source-blending", WGPUFeatureName_DualSourceBlending},
    {"subgroups", WGPUFeatureName_Subgroups},
    {"texture-formats-tier1", WGPUFeatureName_TextureFormatsTier1},
    {"texture-formats-tier2", WGPUFeatureName_TextureFormatsTier2},
    {"primitive-index", WGPUFeatureName_PrimitiveIndex},
};

static const Entry<WGPUBufferBindingType> kBufferBindingTypes[] = {
    {"uniform", WGPUBufferBindingType_Uniform}, {"storage", WGPUBufferBindingType_Storage},
    {"read-only-storage", WGPUBufferBindingType_ReadOnlyStorage}};
static const Entry<WGPUSamplerBindingType> kSamplerBindingTypes[] = {
    {"filtering", WGPUSamplerBindingType_Filtering}, {"non-filtering", WGPUSamplerBindingType_NonFiltering},
    {"comparison", WGPUSamplerBindingType_Comparison}};
static const Entry<WGPUTextureSampleType> kSampleTypes[] = {
    {"float", WGPUTextureSampleType_Float}, {"unfilterable-float", WGPUTextureSampleType_UnfilterableFloat},
    {"depth", WGPUTextureSampleType_Depth}, {"sint", WGPUTextureSampleType_Sint}, {"uint", WGPUTextureSampleType_Uint}};
static const Entry<WGPUStorageTextureAccess> kStorageAccess[] = {
    {"write-only", WGPUStorageTextureAccess_WriteOnly}, {"read-only", WGPUStorageTextureAccess_ReadOnly},
    {"read-write", WGPUStorageTextureAccess_ReadWrite}};
static const Entry<WGPUTextureViewDimension> kViewDimensions[] = {
    {"1d", WGPUTextureViewDimension_1D}, {"2d", WGPUTextureViewDimension_2D},
    {"2d-array", WGPUTextureViewDimension_2DArray}, {"cube", WGPUTextureViewDimension_Cube},
    {"cube-array", WGPUTextureViewDimension_CubeArray}, {"3d", WGPUTextureViewDimension_3D}};
static const Entry<WGPUTextureDimension> kDimensions[] = {
    {"1d", WGPUTextureDimension_1D}, {"2d", WGPUTextureDimension_2D}, {"3d", WGPUTextureDimension_3D}};
static const Entry<WGPUAddressMode> kAddressModes[] = {
    {"clamp-to-edge", WGPUAddressMode_ClampToEdge}, {"repeat", WGPUAddressMode_Repeat},
    {"mirror-repeat", WGPUAddressMode_MirrorRepeat}};
static const Entry<WGPUFilterMode> kFilterModes[] = {{"nearest", WGPUFilterMode_Nearest}, {"linear", WGPUFilterMode_Linear}};
static const Entry<WGPUMipmapFilterMode> kMipmapFilterModes[] = {
    {"nearest", WGPUMipmapFilterMode_Nearest}, {"linear", WGPUMipmapFilterMode_Linear}};
static const Entry<WGPUCompareFunction> kCompareFunctions[] = {
    {"never", WGPUCompareFunction_Never}, {"less", WGPUCompareFunction_Less}, {"equal", WGPUCompareFunction_Equal},
    {"less-equal", WGPUCompareFunction_LessEqual}, {"greater", WGPUCompareFunction_Greater},
    {"not-equal", WGPUCompareFunction_NotEqual}, {"greater-equal", WGPUCompareFunction_GreaterEqual},
    {"always", WGPUCompareFunction_Always}};
static const Entry<WGPULoadOp> kLoadOps[] = {{"load", WGPULoadOp_Load}, {"clear", WGPULoadOp_Clear}};
static const Entry<WGPUStoreOp> kStoreOps[] = {{"store", WGPUStoreOp_Store}, {"discard", WGPUStoreOp_Discard}};
static const Entry<WGPUPrimitiveTopology> kTopologies[] = {
    {"point-list", WGPUPrimitiveTopology_PointList}, {"line-list", WGPUPrimitiveTopology_LineList},
    {"line-strip", WGPUPrimitiveTopology_LineStrip}, {"triangle-list", WGPUPrimitiveTopology_TriangleList},
    {"triangle-strip", WGPUPrimitiveTopology_TriangleStrip}};
static const Entry<WGPUIndexFormat> kIndexFormats[] = {{"uint16", WGPUIndexFormat_Uint16}, {"uint32", WGPUIndexFormat_Uint32}};
static const Entry<WGPUFrontFace> kFrontFaces[] = {{"ccw", WGPUFrontFace_CCW}, {"cw", WGPUFrontFace_CW}};
static const Entry<WGPUCullMode> kCullModes[] = {{"none", WGPUCullMode_None}, {"front", WGPUCullMode_Front}, {"back", WGPUCullMode_Back}};
static const Entry<WGPUBlendOperation> kBlendOps[] = {
    {"add", WGPUBlendOperation_Add}, {"subtract", WGPUBlendOperation_Subtract},
    {"reverse-subtract", WGPUBlendOperation_ReverseSubtract}, {"min", WGPUBlendOperation_Min}, {"max", WGPUBlendOperation_Max}};
static const Entry<WGPUBlendFactor> kBlendFactors[] = {
    {"zero", WGPUBlendFactor_Zero}, {"one", WGPUBlendFactor_One}, {"src", WGPUBlendFactor_Src},
    {"one-minus-src", WGPUBlendFactor_OneMinusSrc}, {"src-alpha", WGPUBlendFactor_SrcAlpha},
    {"one-minus-src-alpha", WGPUBlendFactor_OneMinusSrcAlpha}, {"dst", WGPUBlendFactor_Dst},
    {"one-minus-dst", WGPUBlendFactor_OneMinusDst}, {"dst-alpha", WGPUBlendFactor_DstAlpha},
    {"one-minus-dst-alpha", WGPUBlendFactor_OneMinusDstAlpha}, {"src-alpha-saturated", WGPUBlendFactor_SrcAlphaSaturated},
    {"constant", WGPUBlendFactor_Constant}, {"one-minus-constant", WGPUBlendFactor_OneMinusConstant},
    {"src1", WGPUBlendFactor_Src1}, {"one-minus-src1", WGPUBlendFactor_OneMinusSrc1},
    {"src1-alpha", WGPUBlendFactor_Src1Alpha}, {"one-minus-src1-alpha", WGPUBlendFactor_OneMinusSrc1Alpha}};
static const Entry<WGPUVertexStepMode> kStepModes[] = {{"vertex", WGPUVertexStepMode_Vertex}, {"instance", WGPUVertexStepMode_Instance}};
static const Entry<WGPUVertexFormat> kVertexFormats[] = {
    {"uint8", WGPUVertexFormat_Uint8}, {"uint8x2", WGPUVertexFormat_Uint8x2}, {"uint8x4", WGPUVertexFormat_Uint8x4},
    {"sint8", WGPUVertexFormat_Sint8}, {"sint8x2", WGPUVertexFormat_Sint8x2}, {"sint8x4", WGPUVertexFormat_Sint8x4},
    {"unorm8", WGPUVertexFormat_Unorm8}, {"unorm8x2", WGPUVertexFormat_Unorm8x2}, {"unorm8x4", WGPUVertexFormat_Unorm8x4},
    {"snorm8", WGPUVertexFormat_Snorm8}, {"snorm8x2", WGPUVertexFormat_Snorm8x2}, {"snorm8x4", WGPUVertexFormat_Snorm8x4},
    {"uint16", WGPUVertexFormat_Uint16}, {"uint16x2", WGPUVertexFormat_Uint16x2}, {"uint16x4", WGPUVertexFormat_Uint16x4},
    {"sint16", WGPUVertexFormat_Sint16}, {"sint16x2", WGPUVertexFormat_Sint16x2}, {"sint16x4", WGPUVertexFormat_Sint16x4},
    {"unorm16", WGPUVertexFormat_Unorm16}, {"unorm16x2", WGPUVertexFormat_Unorm16x2}, {"unorm16x4", WGPUVertexFormat_Unorm16x4},
    {"snorm16", WGPUVertexFormat_Snorm16}, {"snorm16x2", WGPUVertexFormat_Snorm16x2}, {"snorm16x4", WGPUVertexFormat_Snorm16x4},
    {"float16", WGPUVertexFormat_Float16}, {"float16x2", WGPUVertexFormat_Float16x2}, {"float16x4", WGPUVertexFormat_Float16x4},
    {"float32", WGPUVertexFormat_Float32}, {"float32x2", WGPUVertexFormat_Float32x2}, {"float32x3", WGPUVertexFormat_Float32x3},
    {"float32x4", WGPUVertexFormat_Float32x4}, {"uint32", WGPUVertexFormat_Uint32}, {"uint32x2", WGPUVertexFormat_Uint32x2},
    {"uint32x3", WGPUVertexFormat_Uint32x3}, {"uint32x4", WGPUVertexFormat_Uint32x4}, {"sint32", WGPUVertexFormat_Sint32},
    {"sint32x2", WGPUVertexFormat_Sint32x2}, {"sint32x3", WGPUVertexFormat_Sint32x3}, {"sint32x4", WGPUVertexFormat_Sint32x4},
    {"unorm8x4-bgra", WGPUVertexFormat_Unorm8x4BGRA}};
static const Entry<WGPUStencilOperation> kStencilOps[] = {
    {"keep", WGPUStencilOperation_Keep}, {"zero", WGPUStencilOperation_Zero}, {"replace", WGPUStencilOperation_Replace},
    {"invert", WGPUStencilOperation_Invert}, {"increment-clamp", WGPUStencilOperation_IncrementClamp},
    {"decrement-clamp", WGPUStencilOperation_DecrementClamp}, {"increment-wrap", WGPUStencilOperation_IncrementWrap},
    {"decrement-wrap", WGPUStencilOperation_DecrementWrap}};
static const Entry<WGPUTextureAspect> kAspects[] = {
    {"all", WGPUTextureAspect_All}, {"stencil-only", WGPUTextureAspect_StencilOnly}, {"depth-only", WGPUTextureAspect_DepthOnly}};
static const Entry<WGPUCompositeAlphaMode> kAlphaModes[] = {
    {"opaque", WGPUCompositeAlphaMode_Opaque}, {"premultiplied", WGPUCompositeAlphaMode_Premultiplied},
    {"unpremultiplied", WGPUCompositeAlphaMode_Unpremultiplied}, {"inherit", WGPUCompositeAlphaMode_Inherit}};
static const Entry<WGPUQueryType> kQueryTypes[] = {{"occlusion", WGPUQueryType_Occlusion}, {"timestamp", WGPUQueryType_Timestamp}};
static const Entry<WGPUErrorFilter> kErrorFilters[] = {
    {"validation", WGPUErrorFilter_Validation}, {"out-of-memory", WGPUErrorFilter_OutOfMemory}, {"internal", WGPUErrorFilter_Internal}};

} // namespace sg
