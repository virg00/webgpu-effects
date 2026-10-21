#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/PerlinNoise/index.ts @ v4.0.4
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

uvec3 floatBitsToUint3_(vec3 v) {
    return floatBitsToUint(v);
}

vec3 hash33_(vec3 p) {
    uvec3 _e6 = floatBitsToUint3_((p * vec3(141421360.0, 2718281700.0, 1618034000.0)));
    uint h = ((_e6.x ^ _e6.y) ^ _e6.z);
    uvec3 prod = (uvec3(h, h, h) * uvec3(1732050807u, 2645751311u, 3316624790u));
    return (vec3(float(prod.x), float(prod.y), float(prod.z)) / vec3(4294967300.0));
}

float perlinGrad3_(vec3 i, vec3 f, float ox, float oy, float oz) {
    vec3 o = vec3(ox, oy, oz);
    vec3 _e8 = hash33_((i + o));
    return dot((f - o), normalize((_e8 - vec3(0.5))));
}

float perlin13_(vec3 p_1) {
    vec3 i_1 = floor(p_1);
    vec3 f_1 = (p_1 - i_1);
    vec3 u = (((f_1 * f_1) * f_1) * ((f_1 * ((f_1 * 6.0) - vec3(15.0))) + vec3(10.0)));
    float _e18 = perlinGrad3_(i_1, f_1, 0.0, 0.0, 0.0);
    float _e22 = perlinGrad3_(i_1, f_1, 1.0, 0.0, 0.0);
    float _e26 = perlinGrad3_(i_1, f_1, 0.0, 1.0, 0.0);
    float _e30 = perlinGrad3_(i_1, f_1, 1.0, 1.0, 0.0);
    float _e34 = perlinGrad3_(i_1, f_1, 0.0, 0.0, 1.0);
    float _e38 = perlinGrad3_(i_1, f_1, 1.0, 0.0, 1.0);
    float _e42 = perlinGrad3_(i_1, f_1, 0.0, 1.0, 1.0);
    float _e46 = perlinGrad3_(i_1, f_1, 1.0, 1.0, 1.0);
    float z0_ = mix(mix(_e18, _e22, u.x), mix(_e26, _e30, u.x), u.y);
    float z1_ = mix(mix(_e34, _e38, u.x), mix(_e42, _e46, u.x), u.y);
    return ((mix(z0_, z1_, u.z) * 0.7) + 0.5);
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
    float _e25 = _group_0_binding_0_fs.n_n.scale;
    float _e29 = _group_0_binding_0_fs.n_n.seed;
    vec2 _e30 = aspectScaledDomain(_e17, _e21, _e25, _e29);
    float _e34 = _group_0_binding_0_fs.n_n._animTime;
    vec3 _e36 = timeAxisDomain(_e30, _e34, 0.3);
    float _e37 = perlin13_(_e36);
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

