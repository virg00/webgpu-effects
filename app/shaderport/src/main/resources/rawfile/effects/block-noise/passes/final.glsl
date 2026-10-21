#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/BlockNoise/index.ts @ v4.0.4
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
    float colorSpace;
    float scale;
    float contrast;
    float balance;
    float seed;
    float speed;
    float _opacity;
    float _animTime;
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

float noiseToneKColor(float noise01_, float contrast, float balance) {
    float k = clamp(((((noise01_ - 0.5) * (contrast + 1.0)) + 0.5) + balance), 0.0, 1.0);
    return (1.0 - k);
}

vec4 perm4_(vec4 x) {
    vec4 xx = (x * ((x * 34.0) + vec4(1.0)));
    return (xx - (floor((xx / vec4(289.0))) * 289.0));
}

float value13_(vec3 p) {
    vec3 a_1 = floor(p);
    vec3 d0_ = (p - a_1);
    vec3 sd = ((d0_ * d0_) * (vec3(3.0) - (d0_ * 2.0)));
    vec4 b_1 = (vec4(a_1.x, a_1.x, a_1.y, a_1.y) + vec4(0.0, 1.0, 0.0, 1.0));
    vec4 _e26 = perm4_(vec4(b_1.x, b_1.y, b_1.x, b_1.y));
    vec4 _e38 = perm4_((vec4(_e26.x, _e26.y, _e26.x, _e26.y) + vec4(b_1.z, b_1.z, b_1.w, b_1.w)));
    vec4 k2_ = (_e38 + vec4(a_1.z, a_1.z, a_1.z, a_1.z));
    vec4 _e45 = perm4_(k2_);
    vec4 _e49 = perm4_((k2_ + vec4(1.0)));
    vec4 o1_ = fract((_e45 * 0.02439024));
    vec4 o2_ = fract((_e49 * 0.02439024));
    vec4 o3_ = mix(o1_, o2_, vec4(sd.z));
    vec2 o4_ = mix(vec2(o3_.x, o3_.z), vec2(o3_.y, o3_.w), vec2(sd.x));
    return mix(o4_.x, o4_.y, sd.y);
}

vec3 timeAxisDomain(vec2 pos, float t_1, float rate) {
    return vec3(pos.x, pos.y, (t_1 * rate));
}

float geom_aspectOf(vec2 viewport) {
    return (viewport.x / max(viewport.y, 1e-6));
}

vec2 aspectScaledDomain(vec2 uv_1, vec2 viewport_1, float scale, float seed) {
    float _e4 = geom_aspectOf(viewport_1);
    vec2 aspectUV = vec2((uv_1.x * _e4), uv_1.y);
    return ((aspectUV * exp(scale)) + vec2(seed));
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
    vec4 composed_0_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec4 _e12 = _group_0_binding_0_fs.n_n.colorA;
    vec4 _e16 = _group_0_binding_0_fs.n_n.colorB;
    vec2 _e17 = uv;
    vec2 _e21 = _group_0_binding_0_fs._sys.viewportSize;
    float _e25 = _group_0_binding_0_fs.n_n.scale;
    float _e29 = _group_0_binding_0_fs.n_n.seed;
    vec2 _e30 = aspectScaledDomain(_e17, _e21, _e25, _e29);
    float _e34 = _group_0_binding_0_fs.n_n._animTime;
    vec3 _e36 = timeAxisDomain(_e30, _e34, 0.3);
    float _e37 = value13_(_e36);
    float _e41 = _group_0_binding_0_fs.n_n.contrast;
    float _e45 = _group_0_binding_0_fs.n_n.balance;
    float _e46 = noiseToneKColor(_e37, _e41, _e45);
    vec4 _e47 = mixColors(_e12, _e16, _e46);
    composed_0_ = _e47;
    vec4 _e49 = composed_0_;
    vec3 _e51 = tone_linear(_e49.xyz);
    vec3 _e52 = linearToSrgb(_e51);
    float _e54 = composed_0_.w;
    _fs2p_location0 = vec4(_e52, _e54);
    return;
}

