#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/MeshGradient/index.ts @ v4.0.4
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
    float count;
    float smoothness;
    float variation;
    float swirl;
    float drift;
    float wrapping;
    float speed;
    float seed;
    float _opacity;
    float _animTime;
    vec4 meshAnchors[4];
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
struct MixStep {
    vec3 conv;
    float alpha;
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
    float v_2 = ((h < 4u) ? y_1 : inner);
    float uu = (((h & 1u) != 0u) ? -(u) : u);
    float vv = (((h & 2u) != 0u) ? -(v_2) : v_2);
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

vec3 warpDomain(vec3 pos, float t_2, float warpAmount) {
    float _e10 = noise_mxNoiseFloat3_((pos + vec3((t_2 * 0.3), (t_2 * -0.2), 0.0)));
    float _e17 = noise_mxNoiseFloat3_((pos + vec3(5.2, 1.3, (t_2 * 0.25))));
    vec3 warped1_ = (pos + (vec3(_e10, _e17, 0.0) * warpAmount));
    float _e28 = noise_mxNoiseFloat3_((warped1_ + vec3(1.7, 9.2, (t_2 * 0.15))));
    float _e35 = noise_mxNoiseFloat3_((warped1_ + vec3(8.3, 2.8, (t_2 * 0.13))));
    return (pos + (vec3(_e28, _e35, 0.0) * warpAmount));
}

vec3 awMix(vec3 a_1, vec3 b_1, float wA, float wB, float sw) {
    return (((a_1 * wA) + (b_1 * wB)) / vec3(sw));
}

MixStep mixInSpace(vec3 convA, float alphaA, vec3 convB, float alphaB, float t_3) {
    float weightA = (alphaA * (1.0 - t_3));
    float weightB = (alphaB * t_3);
    float totalWeight = (weightA + weightB);
    float safeWeight = max(totalWeight, 0.001);
    vec3 _e12 = awMix(convA, convB, weightA, weightB, safeWeight);
    return MixStep(_e12, totalWeight);
}

MixStep gradientStopsInSpace(float t_4, vec4 colors[8], vec4 positions[2], vec3 converted[8], float stopCount) {
    vec3 conv = vec3(0.0);
    float alpha = 0.0;
    int i = 1;
    float clampedT = clamp(t_4, 0.0, 1.0);
    int n = int(stopCount);
    vec3 c0_1 = converted[0];
    conv = vec3(c0_1.x, c0_1.y, c0_1.z);
    alpha = colors[0].w;
    bool loop_init = true;
    while(true) {
        if (!loop_init) {
            int _e67 = i;
            i = (_e67 + 1);
        }
        loop_init = false;
        int _e20 = i;
        if ((_e20 < n)) {
        } else {
            break;
        }
        {
            int _e22 = i;
            vec4 va = positions[((_e22 - 1) >> 2u)];
            int _e28 = i;
            vec4 vb = positions[(_e28 >> 2u)];
            int _e32 = i;
            float posA = va[((_e32 - 1) & 3)];
            int _e38 = i;
            float posB = vb[(_e38 & 3)];
            float seg = clamp(((clampedT - posA) / max((posB - posA), 1e-6)), 0.0, 1.0);
            vec3 _e50 = conv;
            float _e51 = alpha;
            int _e52 = i;
            int _e54 = i;
            MixStep _e57 = mixInSpace(_e50, _e51, converted[_e52], colors[_e54].w, seg);
            conv = vec3(_e57.conv.x, _e57.conv.y, _e57.conv.z);
            alpha = _e57.alpha;
        }
    }
    vec3 _e69 = conv;
    float _e70 = alpha;
    return MixStep(_e69, _e70);
}

float footprint1_(float x_3, float softness) {
    float _e2 = dFdx(x_3);
    float _e4 = dFdy(x_3);
    float baseW = max(abs(_e2), abs(_e4));
    return max((baseW + softness), 1e-5);
}

float rampWrap(float t_5, float cycles) {
    float s_1 = (t_5 * cycles);
    float m = (fract((s_1 * 0.5)) * 2.0);
    float band = (1.0 - abs((m - 1.0)));
    float _e14 = footprint1_(t_5, 0.0);
    float fp = (_e14 * cycles);
    return mix(band, 0.5, smoothstep(0.5, 1.5, fp));
}

uint floatBitsToUint1_(float x_4) {
    return floatBitsToUint(x_4);
}

float noise_hash11_(float p_2) {
    uint _e3 = floatBitsToUint1_((p_2 * 3141592600.0));
    return (float(((_e3 * _e3) * 3141592653u)) / 4294967300.0);
}

float scatterField(vec2 q, float count, float seed, vec4 anchors[4], float power) {
    float num = 0.0;
    float den = 0.0;
    int i_1 = 0;
    float _e13 = noise_hash11_(((seed * 0.531) + 0.77));
    bool loop_init_1 = true;
    while(true) {
        if (!loop_init_1) {
            int _e57 = i_1;
            i_1 = (_e57 + 1);
        }
        loop_init_1 = false;
        int _e16 = i_1;
        if ((_e16 < 8)) {
        } else {
            break;
        }
        {
            int _e19 = i_1;
            float fi = float(_e19);
            float active_1_ = ((fi < (count - 0.5)) ? 1.0 : 0.0);
            int _e27 = i_1;
            vec4 pair = anchors[uint((float(_e27) / 2.0))];
            int _e35 = i_1;
            vec2 anchor = (((_e35 & 1) == 1) ? pair.zw : pair.xy);
            float dist = max(length((q - anchor)), 0.01);
            float w = (active_1_ / pow(dist, power));
            float ti = fract(((fi * 0.618034) + _e13));
            float _e51 = num;
            num = (_e51 + (w * ti));
            float _e54 = den;
            den = (_e54 + w);
        }
    }
    float _e59 = num;
    float _e60 = den;
    return (_e59 / max(_e60, 1e-6));
}

uvec2 floatBitsToUint2_(vec2 v_1) {
    return floatBitsToUint(v_1);
}

float hash12_(vec2 p_3) {
    uvec2 _e5 = floatBitsToUint2_((p_3 * vec2(141421360.0, 2718281700.0)));
    return (float(((_e5.x ^ _e5.y) * 3141592653u)) / 4294967300.0);
}

vec4 rgbDither(vec4 base, vec2 uv_1, vec2 viewport, float animTime) {
    float _e9 = hash12_(((uv_1 * viewport) + vec2(animTime, (animTime * 1.618))));
    vec3 rgb = clamp((base.xyz + vec3(((_e9 - 0.5) * 0.004))), vec3(0.0), vec3(1.0));
    return vec4(rgb, base.w);
}

vec3 sRGBToP3_(vec3 srgb) {
    float r_1 = (((srgb.x * 0.8224621) + (srgb.y * 0.177538)) + (srgb.z * 0.0));
    float g = (((srgb.x * 0.0331941) + (srgb.y * 0.9668058)) + (srgb.z * 0.0));
    float b_3 = (((srgb.x * 0.0170826) + (srgb.y * 0.0723974)) + (srgb.z * 0.9105199));
    return vec3(r_1, g, b_3);
}

vec3 oklabToRgb(vec3 lab) {
    float L = lab.x;
    float a_3 = lab.y;
    float b_4 = lab.z;
    float l = ((L + (a_3 * 0.39633778)) + (b_4 * 0.21580376));
    float m_1 = ((L - (a_3 * 0.105561346)) - (b_4 * 0.06385417));
    float s_2 = ((L - (a_3 * 0.08948418)) - (b_4 * 1.2914855));
    float l_1 = pow(l, 3.0);
    float m_2 = pow(m_1, 3.0);
    float s_3 = pow(s_2, 3.0);
    return vec3((((l_1 * 4.0767417) - (m_2 * 3.3077116)) + (s_3 * 0.23096994)), (((l_1 * -1.268438) + (m_2 * 2.6097574)) - (s_3 * 0.34131938)), (((l_1 * -0.0041960864) - (m_2 * 0.7034186)) + (s_3 * 1.7076147)));
}

vec3 linearToSrgb(vec3 color) {
    vec3 a_4 = ((pow(color, vec3(0.41666)) * 1.055) - vec3(0.055));
    vec3 b_5 = (color * 12.92);
    bvec3 factor = lessThanEqual(color, vec3(0.0031308));
    return mix(a_4, b_5, factor);
}

vec3 tone_linear(vec3 color_1) {
    return vec3(color_1.x, color_1.y, color_1.z);
}

void main() {
    final_Input in_ = final_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    vec4 composed_9_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    float _e13 = _group_0_binding_0_fs._sys.viewportSize.x;
    float _e18 = _group_0_binding_0_fs._sys.viewportSize.y;
    float aspect_6_ = (_e13 / max(_e18, 1e-6));
    float _e23 = uv.x;
    float _e29 = uv.y;
    vec2 meshCentred_5_ = vec2(((_e23 * aspect_6_) - (aspect_6_ * 0.5)), (_e29 - 0.5));
    float _e36 = _group_0_binding_0_fs.n_n.swirl;
    float swirlAngle_7_ = ((-3.0 * _e36) * smoothstep(0.0, 1.0, length(meshCentred_5_)));
    vec2 meshRot_4_ = vec2(((meshCentred_5_.x * cos(swirlAngle_7_)) - (meshCentred_5_.y * sin(swirlAngle_7_))), ((meshCentred_5_.x * sin(swirlAngle_7_)) + (meshCentred_5_.y * cos(swirlAngle_7_))));
    vec2 meshSwirled_3_ = vec2((meshRot_4_.x + (aspect_6_ * 0.5)), (meshRot_4_.y + 0.5));
    float meshTime_8_ = _group_0_binding_0_fs.n_n._animTime;
    float _e80 = _group_0_binding_0_fs.n_n.seed;
    vec3 _e87 = warpDomain(vec3((meshSwirled_3_.x * 1.6), (meshSwirled_3_.y * 1.6), (_e80 * 7.31)), (meshTime_8_ * 0.125), 0.48);
    vec2 meshQ_1_ = vec2((_e87.x / 1.6), (_e87.y / 1.6));
    float _e98 = _group_0_binding_0_fs.n_n.count;
    float _e102 = _group_0_binding_0_fs.n_n.seed;
    vec4 _e106[4] = _group_0_binding_0_fs.n_n.meshAnchors;
    float _e110 = _group_0_binding_0_fs.n_n.smoothness;
    float _e124 = _group_0_binding_0_fs.n_n.seed;
    float _e131 = noise_mxNoiseFloat3_(vec3((meshQ_1_.x * 1.9), (meshQ_1_.y * 1.9), ((_e124 * 3.17) + (meshTime_8_ * 0.045))));
    float _e135 = _group_0_binding_0_fs.n_n.variation;
    float _e144 = scatterField(meshQ_1_, _e98, _e102, _e106, clamp(((8.0 / (_e110 + 0.5)) * exp(((_e131 * _e135) * 1.4))), 0.6, 16.0));
    float _e148 = _group_0_binding_0_fs.n_n.wrapping;
    float _e153 = rampWrap(_e144, (1.0 + (_e148 * 9.0)));
    vec4 _e157[8] = _group_0_binding_0_fs.n_n.colorsArray;
    vec4 _e161[2] = _group_0_binding_0_fs.n_n.positionsArray;
    vec3 _e165[8] = _group_0_binding_0_fs.n_n.convertedColorsArray;
    float _e169 = _group_0_binding_0_fs.n_n.stopCount;
    MixStep _e170 = gradientStopsInSpace(_e153, _e157, _e161, _e165, _e169);
    vec3 _e172 = oklabToRgb(_e170.conv);
    vec3 _e173 = sRGBToP3_(_e172);
    vec2 _e176 = uv;
    vec2 _e180 = _group_0_binding_0_fs._sys.viewportSize;
    float _e184 = _group_0_binding_0_fs.n_n._animTime;
    vec4 _e185 = rgbDither(vec4(_e173, _e170.alpha), _e176, _e180, _e184);
    composed_9_ = _e185;
    vec4 _e187 = composed_9_;
    vec3 _e189 = tone_linear(_e187.xyz);
    vec3 _e190 = linearToSrgb(_e189);
    float _e192 = composed_9_.w;
    _fs2p_location0 = vec4(_e190, _e192);
    return;
}

