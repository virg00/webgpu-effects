#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Glow/index.ts @ v4.0.4
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
    float intensity;
    float threshold;
    float size;
    float _opacity;
};
struct struct_2_ {
    float density;
    float speed;
    float intensity;
    float warp;
    float contrast;
    float balance;
    vec4 colorA;
    vec4 colorB;
    vec4 colorsArray[8];
    vec4 positionsArray[2];
    vec3 convertedColorsArray[8];
    float stopCount;
    float colorSpace;
    float _opacity;
    float _animTime;
};
struct struct_3_ {
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
    struct_2_ n_base;
    struct_3_ _sys;
};
struct rtt_rtt_0_Input {
    vec2 uv;
};
layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

vec4 overComposite(vec4 base, vec3 blended, float overlayAlpha) {
    float baseWeight = (base.w * (1.0 - overlayAlpha));
    float finalAlpha = (overlayAlpha + baseWeight);
    vec3 rgb = ((blended * overlayAlpha) + (base.xyz * baseWeight));
    return vec4(rgb, finalAlpha);
}

vec4 blend_normal(vec4 base_1, vec4 overlay2_, float opacity) {
    float overlayAlpha_1 = (overlay2_.w * opacity);
    vec4 _e6 = overComposite(base_1, overlay2_.xyz, overlayAlpha_1);
    return _e6;
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

float toneRemap(float v, float glow, float contrast, float balance) {
    float spread = pow(v, (5.0 / glow));
    float contrasted = clamp((((spread - 0.5) * contrast) + 0.5), 0.0, 1.0);
    float balanceShift = ((balance / 100.0) - 0.5);
    float balanced = clamp((contrasted + balanceShift), 0.0, 1.0);
    return (1.0 - balanced);
}

float mxFade(float t_1) {
    return (((t_1 * t_1) * t_1) * ((t_1 * ((t_1 * 6.0) - 15.0)) + 10.0));
}

uint mxRotl32_(uint x, int k) {
    return ((x << uint(k)) | (x >> uint((32 - k))));
}

uint mxBjfinal(uint a0_, uint b0_, uint c0_) {
    uint a_1 = 0u;
    uint b_1 = 0u;
    uint c = 0u;
    a_1 = a0_;
    b_1 = b0_;
    c = c0_;
    uint _e6 = c;
    uint _e7 = b_1;
    c = (_e6 ^ _e7);
    uint _e9 = c;
    uint _e10 = b_1;
    uint _e12 = mxRotl32_(_e10, 14);
    c = (_e9 - _e12);
    uint _e14 = a_1;
    uint _e15 = c;
    a_1 = (_e14 ^ _e15);
    uint _e17 = a_1;
    uint _e18 = c;
    uint _e20 = mxRotl32_(_e18, 11);
    a_1 = (_e17 - _e20);
    uint _e22 = b_1;
    uint _e23 = a_1;
    b_1 = (_e22 ^ _e23);
    uint _e25 = b_1;
    uint _e26 = a_1;
    uint _e28 = mxRotl32_(_e26, 25);
    b_1 = (_e25 - _e28);
    uint _e30 = c;
    uint _e31 = b_1;
    c = (_e30 ^ _e31);
    uint _e33 = c;
    uint _e34 = b_1;
    uint _e36 = mxRotl32_(_e34, 16);
    c = (_e33 - _e36);
    uint _e38 = a_1;
    uint _e39 = c;
    a_1 = (_e38 ^ _e39);
    uint _e41 = a_1;
    uint _e42 = c;
    uint _e44 = mxRotl32_(_e42, 4);
    a_1 = (_e41 - _e44);
    uint _e46 = b_1;
    uint _e47 = a_1;
    b_1 = (_e46 ^ _e47);
    uint _e49 = b_1;
    uint _e50 = a_1;
    uint _e52 = mxRotl32_(_e50, 14);
    b_1 = (_e49 - _e52);
    uint _e54 = c;
    uint _e55 = b_1;
    c = (_e54 ^ _e55);
    uint _e57 = c;
    uint _e58 = b_1;
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
    float v_2 = ((h < 4u) ? y_1 : inner);
    float uu = (((h & 1u) != 0u) ? -(u) : u);
    float vv = (((h & 2u) != 0u) ? -(v_2) : v_2);
    return (uu + vv);
}

float mxTrilerp(float v0_, float v1_, float v2_, float v3_, float v4_, float v5_, float v6_, float v7_, float s, float t_2, float r) {
    float s1_ = (1.0 - s);
    float t1_ = (1.0 - t_2);
    float r1_ = (1.0 - r);
    return ((r1_ * ((t1_ * ((v0_ * s1_) + (v1_ * s))) + (t_2 * ((v2_ * s1_) + (v3_ * s))))) + (r * ((t1_ * ((v4_ * s1_) + (v5_ * s))) + (t_2 * ((v6_ * s1_) + (v7_ * s))))));
}

float mxGradientScale3d(float v_1) {
    return (0.982 * v_1);
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

float unitNoise3_(vec3 pos) {
    float _e1 = noise_mxNoiseFloat3_(pos);
    return ((_e1 * 0.5) + 0.5);
}

vec3 warpDomain(vec3 pos_1, float t_3, float warpAmount) {
    float _e10 = noise_mxNoiseFloat3_((pos_1 + vec3((t_3 * 0.3), (t_3 * -0.2), 0.0)));
    float _e17 = noise_mxNoiseFloat3_((pos_1 + vec3(5.2, 1.3, (t_3 * 0.25))));
    vec3 warped1_ = (pos_1 + (vec3(_e10, _e17, 0.0) * warpAmount));
    float _e28 = noise_mxNoiseFloat3_((warped1_ + vec3(1.7, 9.2, (t_3 * 0.15))));
    float _e35 = noise_mxNoiseFloat3_((warped1_ + vec3(8.3, 2.8, (t_3 * 0.13))));
    return (pos_1 + (vec3(_e28, _e35, 0.0) * warpAmount));
}

float geom_aspectOf(vec2 viewport) {
    return (viewport.x / max(viewport.y, 1e-6));
}

vec3 volumeDomain(vec2 uv_1, vec2 viewport_1, float scale) {
    float _e3 = geom_aspectOf(viewport_1);
    vec3 base_2 = vec3((uv_1.x * _e3), uv_1.y, 0.0);
    return (base_2 * exp((scale - 1.0)));
}

void main() {
    rtt_rtt_0_Input in_ = rtt_rtt_0_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec4 _e17 = _group_0_binding_0_fs.n_base.colorA;
    vec4 _e21 = _group_0_binding_0_fs.n_base.colorB;
    vec2 _e22 = uv;
    vec2 _e26 = _group_0_binding_0_fs._sys.viewportSize;
    float _e30 = _group_0_binding_0_fs.n_base.density;
    vec3 _e31 = volumeDomain(_e22, _e26, _e30);
    float _e35 = _group_0_binding_0_fs.n_base._animTime;
    float _e41 = _group_0_binding_0_fs.n_base.warp;
    vec3 _e44 = warpDomain(_e31, (_e35 * 0.125), (_e41 * 4.0));
    float _e45 = unitNoise3_(_e44);
    float _e49 = _group_0_binding_0_fs.n_base.intensity;
    float _e53 = _group_0_binding_0_fs.n_base.contrast;
    float _e57 = _group_0_binding_0_fs.n_base.balance;
    float _e58 = toneRemap(_e45, _e49, _e53, _e57);
    vec4 _e59 = mixColors(_e17, _e21, _e58);
    float _e63 = _group_0_binding_0_fs.n_base._opacity;
    vec4 _e64 = blend_normal(vec4(1.0, 1.0, 1.0, 0.0), _e59, _e63);
    _fs2p_location0 = _e64;
    return;
}

