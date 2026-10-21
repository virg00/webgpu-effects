#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/RadialGradient/index.ts @ v4.0.4
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
    vec4 colorsArray[8];
    vec4 positionsArray[2];
    vec3 convertedColorsArray[8];
    float stopCount;
    vec2 center;
    float radius;
    float repeat;
    float aspect;
    float skewAngle;
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

float repeatRings(float t_1, float repeat) {
    float s = (t_1 * repeat);
    return ((repeat > 1.0001) ? fract(s) : clamp(s, 0.0, 1.0));
}

vec2 aspectCenteredDelta(vec2 uv_1, vec2 center, vec2 viewport) {
    float aspect = (viewport.x / max(viewport.y, 1e-6));
    return vec2(((uv_1.x * aspect) - (center.x * aspect)), (uv_1.y - (1.0 - center.y)));
}

vec2 rotate2_(vec2 p, float cosA, float sinA) {
    return vec2(((p.x * cosA) - (p.y * sinA)), ((p.x * sinA) + (p.y * cosA)));
}

float radialDist(vec2 center_1, float skewAngle, float ellipseAspect, float radius, vec2 uv_2, vec2 viewport_1) {
    vec2 _e6 = aspectCenteredDelta(uv_2, center_1, viewport_1);
    float skewRad = (skewAngle * 0.017453292);
    float cosS = cos(skewRad);
    float sinS = sin(skewRad);
    vec2 _e12 = rotate2_(_e6, cosS, -(sinS));
    vec2 stretched = vec2((_e12.x * ellipseAspect), _e12.y);
    float dist = length(stretched);
    float safeRadius = max(radius, 1e-6);
    return (dist / safeRadius);
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
    vec2 _e20 = _group_0_binding_0_fs.n_n.center;
    float _e24 = _group_0_binding_0_fs.n_n.skewAngle;
    float _e28 = _group_0_binding_0_fs.n_n.aspect;
    float _e32 = _group_0_binding_0_fs.n_n.radius;
    vec2 _e33 = uv;
    vec2 _e37 = _group_0_binding_0_fs._sys.viewportSize;
    float _e38 = radialDist(_e20, _e24, _e28, _e32, _e33, _e37);
    float _e42 = _group_0_binding_0_fs.n_n.repeat;
    float _e43 = repeatRings(_e38, _e42);
    vec4 _e44 = mixColors(_e12, _e16, _e43);
    composed_0_ = _e44;
    vec4 _e46 = composed_0_;
    vec3 _e48 = tone_linear(_e46.xyz);
    vec3 _e49 = linearToSrgb(_e48);
    float _e51 = composed_0_.w;
    _fs2p_location0 = vec4(_e49, _e51);
    return;
}

