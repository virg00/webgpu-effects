#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Marble/index.ts @ v4.0.4
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
    float scale;
    float turbulence;
    float speed;
    float seed;
    float colorSpace;
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

uint mxHashInt1_(int x_1, int y) {
    uint a_2 = (3735928580u + uint(x_1));
    uint b_2 = (3735928580u + uint(y));
    uint _e7 = mxBjfinal(a_2, b_2, 3735928580u);
    return _e7;
}

float mxGradientFloat2_(uint hash, float x_2, float y_1) {
    uint h = (hash & 7u);
    float u = ((h < 4u) ? x_2 : y_1);
    float v_1 = (2.0 * ((h < 4u) ? y_1 : x_2));
    float uu = (((h & 1u) != 0u) ? -(u) : u);
    float vv = (((h & 2u) != 0u) ? -(v_1) : v_1);
    return (uu + vv);
}

float mxBilerp(float v0_, float v1_, float v2_, float v3_, float s, float t_1) {
    float s1_ = (1.0 - s);
    return (((1.0 - t_1) * ((v0_ * s1_) + (v1_ * s))) + (t_1 * ((v2_ * s1_) + (v3_ * s))));
}

float mxGradientScale2d(float v) {
    return (0.6616 * v);
}

float mxPerlinNoiseFloat2_(vec2 p) {
    int X = int(floor(p.x));
    int Y = int(floor(p.y));
    float fx = (p.x - float(X));
    float fy = (p.y - float(Y));
    float _e13 = mxFade(fx);
    float _e14 = mxFade(fy);
    uint _e15 = mxHashInt1_(X, Y);
    float _e16 = mxGradientFloat2_(_e15, fx, fy);
    uint _e19 = mxHashInt1_((X + 1), Y);
    float _e22 = mxGradientFloat2_(_e19, (fx - 1.0), fy);
    uint _e25 = mxHashInt1_(X, (Y + 1));
    float _e28 = mxGradientFloat2_(_e25, fx, (fy - 1.0));
    uint _e33 = mxHashInt1_((X + 1), (Y + 1));
    float _e38 = mxGradientFloat2_(_e33, (fx - 1.0), (fy - 1.0));
    float _e39 = mxBilerp(_e16, _e22, _e28, _e38, _e13, _e14);
    float _e40 = mxGradientScale2d(_e39);
    return _e40;
}

float mxNoiseFloat2_(vec2 p_1) {
    float _e1 = mxPerlinNoiseFloat2_(p_1);
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
    vec4 composed_5_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    float _e13 = _group_0_binding_0_fs._sys.viewportSize.x;
    float _e18 = _group_0_binding_0_fs._sys.viewportSize.y;
    float aspect_2_ = (_e13 / max(_e18, 1e-6));
    float _e23 = uv.x;
    float _e26 = uv.y;
    float _e31 = _group_0_binding_0_fs.n_n.scale;
    vec2 plane_1_ = (vec2((_e23 * aspect_2_), _e26) * _e31);
    float marbleTime_4_ = _group_0_binding_0_fs.n_n._animTime;
    float _e41 = _group_0_binding_0_fs.n_n.seed;
    float _e46 = mxNoiseFloat2_(vec2((plane_1_.x + _e41), (plane_1_.y + marbleTime_4_)));
    float _e53 = _group_0_binding_0_fs.n_n.seed;
    float _e64 = mxNoiseFloat2_(vec2(((plane_1_.x * 2.0) + (_e53 * 1.7)), ((plane_1_.y * 2.0) + (marbleTime_4_ * 0.7))));
    float _e74 = _group_0_binding_0_fs.n_n.seed;
    float _e85 = mxNoiseFloat2_(vec2(((plane_1_.x * 4.0) + (_e74 * 3.1)), ((plane_1_.y * 4.0) + (marbleTime_4_ * 1.3))));
    float marbleTurb_3_ = ((_e46 + (_e64 * 0.5)) + (_e85 * 0.25));
    float _e95 = _group_0_binding_0_fs.n_n.turbulence;
    float veinT_0_ = ((sin(((plane_1_.x * 3.1415927) + (marbleTurb_3_ * _e95))) * 0.5) + 0.5);
    vec4 _e106 = _group_0_binding_0_fs.n_n.colorA;
    vec4 _e110 = _group_0_binding_0_fs.n_n.colorB;
    vec4 _e114 = mixColors(_e106, _e110, smoothstep(0.3, 0.6, veinT_0_));
    vec4 _e118 = _group_0_binding_0_fs.n_n.colorC;
    float _e128 = _group_0_binding_0_fs.n_n.seed;
    float _e136 = mxNoiseFloat2_(vec2(((plane_1_.y * 1.5) + (_e128 * 2.0)), (plane_1_.x * 1.2)));
    vec4 _e142 = mixColors(_e114, _e118, (smoothstep(0.6, 0.9, veinT_0_) * ((_e136 * 0.3) + 0.5)));
    composed_5_ = _e142;
    vec4 _e144 = composed_5_;
    vec3 _e146 = tone_linear(_e144.xyz);
    vec3 _e147 = linearToSrgb(_e146);
    float _e149 = composed_5_.w;
    _fs2p_location0 = vec4(_e147, _e149);
    return;
}

