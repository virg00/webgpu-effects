#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Grid/index.ts @ v4.0.4
//   changes: WGSL -> GLSL ES 3.00 via naga 30.0.1; no manual edits
//   license: MIT (this file) ; Apache-2.0 (project)

precision highp float;
precision highp int;

struct padded {
    float _opacity;
    float _pad0_;
    float _pad1_;
    float _pad2_;
};
struct struct_1_ {
    vec4 color;
    vec4 cellColor;
    float cells;
    float thickness;
    float rotation;
    float softness;
    float variation;
    float colorSpace;
    float _opacity;
};
struct struct_2_ {
    float time;
    vec2 viewportSize;
    vec2 logicalViewportSize;
    float aspect;
    vec2 pointer;
    float pointerActive;
};
struct combined {
    padded n_root;
    struct_1_ n_n;
    struct_2_ _sys;
};
struct final_Input {
    vec2 uv;
};
layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

float quilezLineFilterAxis(float p, float w, float N) {
    float a_1 = (p + (w * 0.5));
    float b_1 = (p - (w * 0.5));
    return ((((floor(a_1) + min((fract(a_1) * N), 1.0)) - floor(b_1)) - min((fract(b_1) * N), 1.0)) / (N * w));
}

float cellHash(vec2 id) {
    vec2 q0_ = fract((id * vec2(123.34, 345.45)));
    vec2 q1_ = (q0_ + vec2(dot(q0_, (q0_ + vec2(34.345)))));
    return fract((q1_.x * q1_.y));
}

float variationFactor(float rand, float variation) {
    return max((1.0 + (((rand - 0.5) * 2.0) * variation)), 0.0);
}

float cellVariation(vec2 cellId, float variation_1) {
    float _e2 = cellHash(cellId);
    float _e3 = variationFactor(_e2, variation_1);
    return _e3;
}

vec2 gridField(vec2 gridUV, float thickness, float softness, float variation_2) {
    float lineWidth = (thickness * 0.01);
    float safeLine = max(lineWidth, 0.0001);
    float lineFraction = (safeLine * 2.0);
    float N_1 = (1.0 / lineFraction);
    vec2 p_2 = (gridUV + vec2(safeLine));
    vec2 dpx = dFdx(p_2);
    vec2 dpy = dFdy(p_2);
    float wx = (max(max(abs(dpx.x), abs(dpy.x)), 1e-5) + softness);
    float wy = (max(max(abs(dpx.y), abs(dpy.y)), 1e-5) + softness);
    float _e33 = quilezLineFilterAxis(p_2.x, wx, N_1);
    float _e35 = quilezLineFilterAxis(p_2.y, wy, N_1);
    float gapBoth = ((1.0 - _e33) * (1.0 - _e35));
    float gridMask = ((1.0 - gapBoth) * step(0.0001, lineWidth));
    float _e47 = cellVariation(floor(gridUV), variation_2);
    return vec2(gridMask, _e47);
}

float geom_aspectOf(vec2 viewport) {
    return (viewport.x / max(viewport.y, 1e-6));
}

vec2 rotateAboutCanvasCentre(vec2 p_1, float aspect, float cosA, float sinA) {
    float centerX = (aspect * 0.5);
    float cx = (p_1.x - centerX);
    float cy = (p_1.y - 0.5);
    return vec2((((cx * cosA) - (cy * sinA)) + centerX), (((cx * sinA) + (cy * cosA)) + 0.5));
}

vec2 latticeFrameFlipY(vec2 uv_1, vec2 viewport_1, float cells, float rotationDeg) {
    float _e4 = geom_aspectOf(viewport_1);
    vec2 correctedUV = vec2((uv_1.x * _e4), (1.0 - uv_1.y));
    float rotRad = (rotationDeg * 0.017453292);
    float cosR = cos(rotRad);
    float sinR = sin(rotRad);
    vec2 _e15 = rotateAboutCanvasCentre(correctedUV, _e4, cosR, sinR);
    return (_e15 * cells);
}

vec3 awMix(vec3 a, vec3 b, float wA, float wB, float sw) {
    return (((a * wA) + (b * wB)) / vec3(sw));
}

vec4 mixColors(vec4 colorA, vec4 colorB, float t) {
    float weightA = (colorA.w * (1.0 - t));
    float weightB = (colorB.w * t);
    float totalWeight = (weightA + weightB);
    float safeWeight = max(totalWeight, 0.001);
    vec3 _e14 = awMix(colorA.xyz, colorB.xyz, weightA, weightB, safeWeight);
    return vec4(_e14, totalWeight);
}

vec3 linearToSrgb(vec3 color) {
    vec3 a_2 = ((pow(color, vec3(0.41666)) * 1.055) - vec3(0.055));
    vec3 b_2 = (color * 12.92);
    bvec3 factor = lessThanEqual(color, vec3(0.0031308));
    return mix(a_2, b_2, factor);
}

vec3 tone_linear(vec3 color_1) {
    return vec3(color_1.x, color_1.y, color_1.z);
}

void main() {
    final_Input in_ = final_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    vec4 composed_1_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec2 _e9 = uv;
    vec2 _e13 = _group_0_binding_0_fs._sys.viewportSize;
    float _e17 = _group_0_binding_0_fs.n_n.cells;
    float _e21 = _group_0_binding_0_fs.n_n.rotation;
    vec2 _e22 = latticeFrameFlipY(_e9, _e13, _e17, _e21);
    float _e26 = _group_0_binding_0_fs.n_n.thickness;
    float _e30 = _group_0_binding_0_fs.n_n.softness;
    float _e34 = _group_0_binding_0_fs.n_n.variation;
    vec2 _e35 = gridField(_e22, _e26, _e30, _e34);
    vec4 _e39 = _group_0_binding_0_fs.n_n.cellColor;
    float _e47 = _group_0_binding_0_fs.n_n.cellColor.w;
    vec4 _e52 = _group_0_binding_0_fs.n_n.color;
    vec4 _e54 = mixColors(vec4((_e39.xyz * _e35.y), _e47), _e52, _e35.x);
    composed_1_ = _e54;
    vec4 _e56 = composed_1_;
    vec3 _e58 = tone_linear(_e56.xyz);
    vec3 _e59 = linearToSrgb(_e58);
    float _e61 = composed_1_.w;
    _fs2p_location0 = vec4(_e59, _e61);
    return;
}

