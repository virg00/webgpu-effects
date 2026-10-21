#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Checkerboard/index.ts @ v4.0.4
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
    vec4 colorA;
    vec4 colorB;
    float cells;
    float softness;
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

vec2 aspectCorrectedUVFlipY(vec2 uv_1, vec2 viewport) {
    float aspect = (viewport.x / max(viewport.y, 1e-6));
    return vec2((uv_1.x * aspect), (1.0 - uv_1.y));
}

vec2 footprint2_(vec2 p, float softness) {
    vec2 dpx = dFdx(p);
    vec2 dpy = dFdy(p);
    vec2 baseW = vec2(max(abs(dpx.x), abs(dpy.x)), max(abs(dpx.y), abs(dpy.y)));
    return vec2(max((baseW.x + softness), 1e-5), max((baseW.y + softness), 1e-5));
}

float quilezCheckerFilter(vec2 p_1, vec2 w) {
    vec2 aHalf = vec2((w.x * 0.5), (w.y * 0.5));
    float minusSideX = abs((fract(((p_1.x - aHalf.x) * 0.5)) - 0.5));
    float minusSideY = abs((fract(((p_1.y - aHalf.y) * 0.5)) - 0.5));
    float plusSideX = abs((fract(((p_1.x + aHalf.x) * 0.5)) - 0.5));
    float plusSideY = abs((fract(((p_1.y + aHalf.y) * 0.5)) - 0.5));
    float iX = (((minusSideX - plusSideX) * 2.0) / w.x);
    float iY = (((minusSideY - plusSideY) * 2.0) / w.y);
    return clamp((0.5 - ((iX * iY) * 0.5)), 0.0, 1.0);
}

float checkerBlend(vec2 uv_2, vec2 viewport_1, float cells, float softness_1) {
    vec2 _e4 = aspectCorrectedUVFlipY(uv_2, viewport_1);
    vec2 p_2 = (_e4 * cells);
    vec2 _e6 = footprint2_(p_2, softness_1);
    float _e7 = quilezCheckerFilter(p_2, _e6);
    return _e7;
}

vec3 linearToSrgb(vec3 color) {
    vec3 a_1 = ((pow(color, vec3(0.41666)) * 1.055) - vec3(0.055));
    vec3 b_1 = (color * 12.92);
    bvec3 factor = lessThanEqual(color, vec3(0.0031308));
    return mix(a_1, b_1, factor);
}

vec3 tone_linear(vec3 color_1) {
    return vec3(color_1.x, color_1.y, color_1.z);
}

void main() {
    final_Input in_ = final_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    vec4 composed_0_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec4 _e12 = _group_0_binding_0_fs.n_n.colorA;
    vec4 _e16 = _group_0_binding_0_fs.n_n.colorB;
    vec2 _e17 = uv;
    vec2 _e21 = _group_0_binding_0_fs._sys.viewportSize;
    float _e25 = _group_0_binding_0_fs.n_n.cells;
    float _e29 = _group_0_binding_0_fs.n_n.softness;
    float _e30 = checkerBlend(_e17, _e21, _e25, _e29);
    vec4 _e31 = mixColors(_e12, _e16, _e30);
    composed_0_ = _e31;
    vec4 _e33 = composed_0_;
    vec3 _e35 = tone_linear(_e33.xyz);
    vec3 _e36 = linearToSrgb(_e35);
    float _e38 = composed_0_.w;
    _fs2p_location0 = vec4(_e36, _e38);
    return;
}

