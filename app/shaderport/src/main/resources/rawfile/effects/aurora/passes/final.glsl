#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Aurora/index.ts @ v4.0.4
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
    vec4 colorC;
    float colorSpace;
    float balance;
    float intensity;
    float curtainCount;
    float speed;
    float waviness;
    float rayDensity;
    float height;
    vec2 center;
    float seed;
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

float mxFade(float t) {
    return (((t * t) * t) * ((t * ((t * 6.0) - 15.0)) + 10.0));
}

uint mxRotl32_(uint x, int k) {
    return ((x << uint(k)) | (x >> uint((32 - k))));
}

uint mxBjfinal(uint a0_, uint b0_, uint c0_) {
    uint a = 0u;
    uint b = 0u;
    uint c = 0u;
    a = a0_;
    b = b0_;
    c = c0_;
    uint _e6 = c;
    uint _e7 = b;
    c = (_e6 ^ _e7);
    uint _e9 = c;
    uint _e10 = b;
    uint _e12 = mxRotl32_(_e10, 14);
    c = (_e9 - _e12);
    uint _e14 = a;
    uint _e15 = c;
    a = (_e14 ^ _e15);
    uint _e17 = a;
    uint _e18 = c;
    uint _e20 = mxRotl32_(_e18, 11);
    a = (_e17 - _e20);
    uint _e22 = b;
    uint _e23 = a;
    b = (_e22 ^ _e23);
    uint _e25 = b;
    uint _e26 = a;
    uint _e28 = mxRotl32_(_e26, 25);
    b = (_e25 - _e28);
    uint _e30 = c;
    uint _e31 = b;
    c = (_e30 ^ _e31);
    uint _e33 = c;
    uint _e34 = b;
    uint _e36 = mxRotl32_(_e34, 16);
    c = (_e33 - _e36);
    uint _e38 = a;
    uint _e39 = c;
    a = (_e38 ^ _e39);
    uint _e41 = a;
    uint _e42 = c;
    uint _e44 = mxRotl32_(_e42, 4);
    a = (_e41 - _e44);
    uint _e46 = b;
    uint _e47 = a;
    b = (_e46 ^ _e47);
    uint _e49 = b;
    uint _e50 = a;
    uint _e52 = mxRotl32_(_e50, 14);
    b = (_e49 - _e52);
    uint _e54 = c;
    uint _e55 = b;
    c = (_e54 ^ _e55);
    uint _e57 = c;
    uint _e58 = b;
    uint _e60 = mxRotl32_(_e58, 24);
    c = (_e57 - _e60);
    uint _e62 = c;
    return _e62;
}

uint mxHashInt2_(int x_1, int y, int z) {
    uint a_2 = (3735928584u + uint(x_1));
    uint b_2 = (3735928584u + uint(y));
    uint c_1 = (3735928584u + uint(z));
    uint _e10 = mxBjfinal(a_2, b_2, c_1);
    return _e10;
}

float mxGradientFloat3_(uint hash, float x_2, float y_1, float z_1) {
    bool local = false;
    uint h = (hash & 15u);
    float u = ((h < 8u) ? x_2 : y_1);
    if (!((h == 12u))) {
        local = (h == 14u);
    } else {
        local = true;
    }
    bool _e17 = local;
    float inner = (_e17 ? x_2 : z_1);
    float v_1 = ((h < 4u) ? y_1 : inner);
    float uu = (((h & 1u) != 0u) ? -(u) : u);
    float vv = (((h & 2u) != 0u) ? -(v_1) : v_1);
    return (uu + vv);
}

float mxTrilerp(float v0_, float v1_, float v2_, float v3_, float v4_, float v5_, float v6_, float v7_, float s, float t_1, float r) {
    float s1_ = (1.0 - s);
    float t1_ = (1.0 - t_1);
    float r1_ = (1.0 - r);
    return ((r1_ * ((t1_ * ((v0_ * s1_) + (v1_ * s))) + (t_1 * ((v2_ * s1_) + (v3_ * s))))) + (r * ((t1_ * ((v4_ * s1_) + (v5_ * s))) + (t_1 * ((v6_ * s1_) + (v7_ * s))))));
}

float mxGradientScale3d(float v) {
    return (0.982 * v);
}

float mxPerlinNoiseFloat3_(vec3 p) {
    int X = int(floor(p.x));
    int Y = int(floor(p.y));
    int Z = int(floor(p.z));
    float fx = (p.x - float(X));
    float fy = (p.y - float(Y));
    float fz = (p.z - float(Z));
    float _e19 = mxFade(fx);
    float _e20 = mxFade(fy);
    float _e21 = mxFade(fz);
    uint _e22 = mxHashInt2_(X, Y, Z);
    float _e23 = mxGradientFloat3_(_e22, fx, fy, fz);
    uint _e26 = mxHashInt2_((X + 1), Y, Z);
    float _e29 = mxGradientFloat3_(_e26, (fx - 1.0), fy, fz);
    uint _e32 = mxHashInt2_(X, (Y + 1), Z);
    float _e35 = mxGradientFloat3_(_e32, fx, (fy - 1.0), fz);
    uint _e40 = mxHashInt2_((X + 1), (Y + 1), Z);
    float _e45 = mxGradientFloat3_(_e40, (fx - 1.0), (fy - 1.0), fz);
    uint _e48 = mxHashInt2_(X, Y, (Z + 1));
    float _e51 = mxGradientFloat3_(_e48, fx, fy, (fz - 1.0));
    uint _e56 = mxHashInt2_((X + 1), Y, (Z + 1));
    float _e61 = mxGradientFloat3_(_e56, (fx - 1.0), fy, (fz - 1.0));
    uint _e66 = mxHashInt2_(X, (Y + 1), (Z + 1));
    float _e71 = mxGradientFloat3_(_e66, fx, (fy - 1.0), (fz - 1.0));
    uint _e78 = mxHashInt2_((X + 1), (Y + 1), (Z + 1));
    float _e85 = mxGradientFloat3_(_e78, (fx - 1.0), (fy - 1.0), (fz - 1.0));
    float _e86 = mxTrilerp(_e23, _e29, _e35, _e45, _e51, _e61, _e71, _e85, _e19, _e20, _e21);
    float _e87 = mxGradientScale3d(_e86);
    return _e87;
}

float noise_mxNoiseFloat3_(vec3 p_1) {
    float _e1 = mxPerlinNoiseFloat3_(p_1);
    return _e1;
}

vec3 awMix(vec3 a_1, vec3 b_1, float wA, float wB, float sw) {
    return (((a_1 * wA) + (b_1 * wB)) / vec3(sw));
}

vec4 mixColors(vec4 colorA, vec4 colorB, float t_2) {
    float weightA = (colorA.w * (1.0 - t_2));
    float weightB = (colorB.w * t_2);
    float totalWeight = (weightA + weightB);
    float safeWeight = max(totalWeight, 0.001);
    vec3 _e14 = awMix(colorA.xyz, colorB.xyz, weightA, weightB, safeWeight);
    return vec4(_e14, totalWeight);
}

vec3 linearToSrgb(vec3 color) {
    vec3 a_3 = ((pow(color, vec3(0.41666)) * 1.055) - vec3(0.055));
    vec3 b_3 = (color * 12.92);
    bvec3 factor = lessThanEqual(color, vec3(0.0031308));
    return mix(a_3, b_3, factor);
}

vec3 tone_linear(vec3 color_1) {
    return vec3(color_1.x, color_1.y, color_1.z);
}

void main() {
    final_Input in_ = final_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    vec4 composed_41_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    float _e13 = _group_0_binding_0_fs._sys.viewportSize.x;
    float _e18 = _group_0_binding_0_fs._sys.viewportSize.y;
    float aspect_4_ = (_e13 / max(_e18, 1e-6));
    float _e23 = uv.x;
    float _e28 = _group_0_binding_0_fs.n_n.center.x;
    float wx_3_ = (((_e23 - _e28) * aspect_4_) * 2.0);
    float auroraTime_6_ = _group_0_binding_0_fs.n_n._animTime;
    float tSlow_5_ = ((auroraTime_6_ * 0.06) + 0.0);
    float _e44 = _group_0_binding_0_fs.n_n.seed;
    float lSeed_7_ = (_e44 + 0.0);
    float _e54 = noise_mxNoiseFloat3_(vec3((wx_3_ * 0.5), (tSlow_5_ * 0.25), (lSeed_7_ * 0.1)));
    float _e56 = uv.y;
    float _e61 = _group_0_binding_0_fs.n_n.center.y;
    float _e120 = _group_0_binding_0_fs.n_n.waviness;
    float _e130 = _group_0_binding_0_fs.n_n.waviness;
    float distFromPath_2_ = (_e56 - (((1.0 - _e61) + ((((sin((((wx_3_ * 0.7) + (tSlow_5_ * 0.4)) + (fract((sin((lSeed_7_ * 12.9)) * 4758.5)) * 6.2831855))) * 0.15) + (sin((((wx_3_ * 1.6) + (tSlow_5_ * 0.65)) + (fract((sin((lSeed_7_ * 78.2)) * 2847.1)) * 6.2831855))) * 0.08)) + (sin((((wx_3_ * 2.9) + (tSlow_5_ * 0.3)) + (fract((sin((lSeed_7_ * 41.6)) * 1593.7)) * 6.2831855))) * 0.04)) * (_e120 * 0.01))) + ((_e54 * 0.14) * (_e130 * 0.01))));
    float _e142 = _group_0_binding_0_fs.n_n.rayDensity;
    float curtainRays_10_ = pow(((sin(((((wx_3_ + (_e54 * 2.5)) * (mix(6.0, 20.0, (_e142 * 0.01)) * 0.15)) + (tSlow_5_ * 0.1)) + (fract((sin((lSeed_7_ * 53.7)) * 3847.2)) * 6.2831855))) * 0.5) + 0.5), 1.5);
    float _e173 = _group_0_binding_0_fs.n_n.height;
    float topExtent_9_ = (((_e173 * 0.01) * mix(0.4, 1.0, curtainRays_10_)) * ((curtainRays_10_ * 0.4) + 0.6));
    float colorT_1_ = clamp((distFromPath_2_ / (topExtent_9_ + 0.001)), 0.0, 1.0);
    float curtainAlpha_11_ = ((((smoothstep(-0.04, 0.015, distFromPath_2_) * (1.0 - smoothstep(0.0, topExtent_9_, distFromPath_2_))) * curtainRays_10_) * mix(0.4, 1.0, ((_e54 * 0.5) + 0.5))) * ((exp((((colorT_1_ - 0.2) * (colorT_1_ - 0.2)) * -6.0)) * 0.3) + 1.0));
    float _e222 = uv.x;
    float _e227 = _group_0_binding_0_fs.n_n.center.x;
    float wx_14_ = (((_e222 - _e227) * aspect_4_) * 2.0);
    float tSlow_15_ = ((auroraTime_6_ * 0.06) + 3.1);
    float _e239 = _group_0_binding_0_fs.n_n.seed;
    float lSeed_16_ = (_e239 + 31.7);
    float _e249 = noise_mxNoiseFloat3_(vec3((wx_14_ * 0.5), (tSlow_15_ * 0.25), (lSeed_16_ * 0.1)));
    float _e251 = uv.y;
    float _e256 = _group_0_binding_0_fs.n_n.center.y;
    float _e315 = _group_0_binding_0_fs.n_n.waviness;
    float _e325 = _group_0_binding_0_fs.n_n.waviness;
    float distFromPath_13_ = (_e251 - (((1.0 - _e256) + ((((sin((((wx_14_ * 0.7) + (tSlow_15_ * 0.4)) + (fract((sin((lSeed_16_ * 12.9)) * 4758.5)) * 6.2831855))) * 0.15) + (sin((((wx_14_ * 1.6) + (tSlow_15_ * 0.65)) + (fract((sin((lSeed_16_ * 78.2)) * 2847.1)) * 6.2831855))) * 0.08)) + (sin((((wx_14_ * 2.9) + (tSlow_15_ * 0.3)) + (fract((sin((lSeed_16_ * 41.6)) * 1593.7)) * 6.2831855))) * 0.04)) * (_e315 * 0.01))) + ((_e249 * 0.14) * (_e325 * 0.01))));
    float _e337 = _group_0_binding_0_fs.n_n.rayDensity;
    float curtainRays_19_ = pow(((sin(((((wx_14_ + (_e249 * 2.5)) * (mix(6.0, 20.0, (_e337 * 0.01)) * 0.15)) + (tSlow_15_ * 0.1)) + (fract((sin((lSeed_16_ * 53.7)) * 3847.2)) * 6.2831855))) * 0.5) + 0.5), 1.5);
    float _e368 = _group_0_binding_0_fs.n_n.height;
    float topExtent_18_ = (((_e368 * 0.01) * mix(0.4, 1.0, curtainRays_19_)) * ((curtainRays_19_ * 0.4) + 0.6));
    float colorT_12_ = clamp((distFromPath_13_ / (topExtent_18_ + 0.001)), 0.0, 1.0);
    float curtainAlpha_20_ = ((((smoothstep(-0.04, 0.015, distFromPath_13_) * (1.0 - smoothstep(0.0, topExtent_18_, distFromPath_13_))) * curtainRays_19_) * mix(0.4, 1.0, ((_e249 * 0.5) + 0.5))) * ((exp((((colorT_12_ - 0.2) * (colorT_12_ - 0.2)) * -6.0)) * 0.3) + 1.0));
    float _e417 = uv.x;
    float _e422 = _group_0_binding_0_fs.n_n.center.x;
    float wx_23_ = (((_e417 - _e422) * aspect_4_) * 2.0);
    float tSlow_24_ = ((auroraTime_6_ * 0.06) + 6.7);
    float _e434 = _group_0_binding_0_fs.n_n.seed;
    float lSeed_25_ = (_e434 + 63.4);
    float _e444 = noise_mxNoiseFloat3_(vec3((wx_23_ * 0.5), (tSlow_24_ * 0.25), (lSeed_25_ * 0.1)));
    float _e446 = uv.y;
    float _e451 = _group_0_binding_0_fs.n_n.center.y;
    float _e510 = _group_0_binding_0_fs.n_n.waviness;
    float _e520 = _group_0_binding_0_fs.n_n.waviness;
    float distFromPath_22_ = (_e446 - (((1.0 - _e451) + ((((sin((((wx_23_ * 0.7) + (tSlow_24_ * 0.4)) + (fract((sin((lSeed_25_ * 12.9)) * 4758.5)) * 6.2831855))) * 0.15) + (sin((((wx_23_ * 1.6) + (tSlow_24_ * 0.65)) + (fract((sin((lSeed_25_ * 78.2)) * 2847.1)) * 6.2831855))) * 0.08)) + (sin((((wx_23_ * 2.9) + (tSlow_24_ * 0.3)) + (fract((sin((lSeed_25_ * 41.6)) * 1593.7)) * 6.2831855))) * 0.04)) * (_e510 * 0.01))) + ((_e444 * 0.14) * (_e520 * 0.01))));
    float _e532 = _group_0_binding_0_fs.n_n.rayDensity;
    float curtainRays_28_ = pow(((sin(((((wx_23_ + (_e444 * 2.5)) * (mix(6.0, 20.0, (_e532 * 0.01)) * 0.15)) + (tSlow_24_ * 0.1)) + (fract((sin((lSeed_25_ * 53.7)) * 3847.2)) * 6.2831855))) * 0.5) + 0.5), 1.5);
    float _e563 = _group_0_binding_0_fs.n_n.height;
    float topExtent_27_ = (((_e563 * 0.01) * mix(0.4, 1.0, curtainRays_28_)) * ((curtainRays_28_ * 0.4) + 0.6));
    float colorT_21_ = clamp((distFromPath_22_ / (topExtent_27_ + 0.001)), 0.0, 1.0);
    float curtainAlpha_29_ = ((((smoothstep(-0.04, 0.015, distFromPath_22_) * (1.0 - smoothstep(0.0, topExtent_27_, distFromPath_22_))) * curtainRays_28_) * mix(0.4, 1.0, ((_e444 * 0.5) + 0.5))) * ((exp((((colorT_21_ - 0.2) * (colorT_21_ - 0.2)) * -6.0)) * 0.3) + 1.0));
    float _e612 = uv.x;
    float _e617 = _group_0_binding_0_fs.n_n.center.x;
    float wx_32_ = (((_e612 - _e617) * aspect_4_) * 2.0);
    float tSlow_33_ = ((auroraTime_6_ * 0.06) + 9.4);
    float _e629 = _group_0_binding_0_fs.n_n.seed;
    float lSeed_34_ = (_e629 + 95.100006);
    float _e639 = noise_mxNoiseFloat3_(vec3((wx_32_ * 0.5), (tSlow_33_ * 0.25), (lSeed_34_ * 0.1)));
    float _e641 = uv.y;
    float _e646 = _group_0_binding_0_fs.n_n.center.y;
    float _e705 = _group_0_binding_0_fs.n_n.waviness;
    float _e715 = _group_0_binding_0_fs.n_n.waviness;
    float distFromPath_31_ = (_e641 - (((1.0 - _e646) + ((((sin((((wx_32_ * 0.7) + (tSlow_33_ * 0.4)) + (fract((sin((lSeed_34_ * 12.9)) * 4758.5)) * 6.2831855))) * 0.15) + (sin((((wx_32_ * 1.6) + (tSlow_33_ * 0.65)) + (fract((sin((lSeed_34_ * 78.2)) * 2847.1)) * 6.2831855))) * 0.08)) + (sin((((wx_32_ * 2.9) + (tSlow_33_ * 0.3)) + (fract((sin((lSeed_34_ * 41.6)) * 1593.7)) * 6.2831855))) * 0.04)) * (_e705 * 0.01))) + ((_e639 * 0.14) * (_e715 * 0.01))));
    float _e727 = _group_0_binding_0_fs.n_n.rayDensity;
    float curtainRays_37_ = pow(((sin(((((wx_32_ + (_e639 * 2.5)) * (mix(6.0, 20.0, (_e727 * 0.01)) * 0.15)) + (tSlow_33_ * 0.1)) + (fract((sin((lSeed_34_ * 53.7)) * 3847.2)) * 6.2831855))) * 0.5) + 0.5), 1.5);
    float _e758 = _group_0_binding_0_fs.n_n.height;
    float topExtent_36_ = (((_e758 * 0.01) * mix(0.4, 1.0, curtainRays_37_)) * ((curtainRays_37_ * 0.4) + 0.6));
    float colorT_30_ = clamp((distFromPath_31_ / (topExtent_36_ + 0.001)), 0.0, 1.0);
    float curtainAlpha_38_ = ((((smoothstep(-0.04, 0.015, distFromPath_31_) * (1.0 - smoothstep(0.0, topExtent_36_, distFromPath_31_))) * curtainRays_37_) * mix(0.4, 1.0, ((_e639 * 0.5) + 0.5))) * ((exp((((colorT_30_ - 0.2) * (colorT_30_ - 0.2)) * -6.0)) * 0.3) + 1.0));
    float auroraAlpha_39_ = (((curtainAlpha_11_ + (curtainAlpha_20_ * 0.65)) + (curtainAlpha_29_ * 0.45)) + (curtainAlpha_38_ * 0.3));
    float _e834 = _group_0_binding_0_fs.n_n.balance;
    float auroraAvgT_0_ = pow((((((colorT_1_ * curtainAlpha_11_) + (colorT_12_ * (curtainAlpha_20_ * 0.65))) + (colorT_21_ * (curtainAlpha_29_ * 0.45))) + (colorT_30_ * (curtainAlpha_38_ * 0.3))) / (auroraAlpha_39_ + 0.001)), mix(2.5, 0.4, (_e834 * 0.01)));
    float _e844 = _group_0_binding_0_fs.n_n.intensity;
    float auroraGlow_40_ = (auroraAlpha_39_ * (_e844 * 0.018));
    vec4 _e851 = _group_0_binding_0_fs.n_n.colorA;
    vec4 _e855 = _group_0_binding_0_fs.n_n.colorB;
    vec4 _e859 = mixColors(_e851, _e855, smoothstep(0.0, 0.2, auroraAvgT_0_));
    vec4 _e863 = _group_0_binding_0_fs.n_n.colorC;
    vec4 _e867 = mixColors(_e859, _e863, smoothstep(0.4, 0.85, auroraAvgT_0_));
    composed_41_ = vec4(clamp((_e867.xyz * auroraGlow_40_), vec3(0.0), vec3(1.0)), clamp((auroraGlow_40_ * 0.5), 0.0, 1.0));
    vec4 _e882 = composed_41_;
    vec3 _e884 = tone_linear(_e882.xyz);
    vec3 _e885 = linearToSrgb(_e884);
    float _e887 = composed_41_.w;
    _fs2p_location0 = vec4(_e885, _e887);
    return;
}

