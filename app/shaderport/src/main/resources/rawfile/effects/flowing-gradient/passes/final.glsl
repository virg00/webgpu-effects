#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/FlowingGradient/index.ts @ v4.0.4
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
    vec4 colorD;
    float colorSpace;
    float speed;
    float distortion;
    float seed;
    float _opacity;
    float _animTime;
    vec3 convA;
    vec3 convB;
    vec3 convC;
    vec3 convD;
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

vec4 chainedWarpStep(vec2 pos, float scale, float z_2, vec2 offA, vec2 offB, float k_1, float strength) {
    vec3 wp = vec3((pos.x * scale), (pos.y * scale), z_2);
    float _e17 = noise_mxNoiseFloat3_((wp + vec3(offA.x, offA.y, 0.0)));
    float _e23 = noise_mxNoiseFloat3_((wp + vec3(offB.x, offB.y, 0.0)));
    return vec4((pos.x + ((_e17 * k_1) * strength)), (pos.y + ((_e23 * k_1) * strength)), _e17, _e23);
}

vec3 awMix(vec3 a_1, vec3 b_1, float wA, float wB, float sw) {
    return (((a_1 * wA) + (b_1 * wB)) / vec3(sw));
}

MixStep mixInSpace(vec3 convA, float alphaA, vec3 convB, float alphaB, float t_2) {
    float weightA = (alphaA * (1.0 - t_2));
    float weightB = (alphaB * t_2);
    float totalWeight = (weightA + weightB);
    float safeWeight = max(totalWeight, 0.001);
    vec3 _e12 = awMix(convA, convB, weightA, weightB, safeWeight);
    return MixStep(_e12, totalWeight);
}

vec3 oklchToOklab(vec3 lch) {
    float L = lch.x;
    float C = lch.y;
    float h_1 = lch.z;
    return vec3(L, (C * cos(h_1)), (C * sin(h_1)));
}

vec3 oklabToRgb(vec3 lab) {
    float L_1 = lab.x;
    float a_3 = lab.y;
    float b_3 = lab.z;
    float l = ((L_1 + (a_3 * 0.39633778)) + (b_3 * 0.21580376));
    float m = ((L_1 - (a_3 * 0.105561346)) - (b_3 * 0.06385417));
    float s_1 = ((L_1 - (a_3 * 0.08948418)) - (b_3 * 1.2914855));
    float l_1 = pow(l, 3.0);
    float m_1 = pow(m, 3.0);
    float s_2 = pow(s_1, 3.0);
    return vec3((((l_1 * 4.0767417) - (m_1 * 3.3077116)) + (s_2 * 0.23096994)), (((l_1 * -1.268438) + (m_1 * 2.6097574)) - (s_2 * 0.34131938)), (((l_1 * -0.0041960864) - (m_1 * 0.7034186)) + (s_2 * 1.7076147)));
}

vec3 sRGBToP3_(vec3 srgb) {
    float r_1 = (((srgb.x * 0.8224621) + (srgb.y * 0.177538)) + (srgb.z * 0.0));
    float g = (((srgb.x * 0.0331941) + (srgb.y * 0.9668058)) + (srgb.z * 0.0));
    float b_4 = (((srgb.x * 0.0170826) + (srgb.y * 0.0723974)) + (srgb.z * 0.9105199));
    return vec3(r_1, g, b_4);
}

vec4 mixPreconvertedColors(vec3 convA_1, vec3 convB_1, float alphaA_1, float alphaB_1, float t_3) {
    float weightA_1 = (alphaA_1 * (1.0 - t_3));
    float weightB_1 = (alphaB_1 * t_3);
    float totalWeight_1 = (weightA_1 + weightB_1);
    float safeWeight_1 = max(totalWeight_1, 0.001);
    vec3 _e12 = awMix(convA_1, convB_1, weightA_1, weightB_1, safeWeight_1);
    vec3 _e13 = oklchToOklab(_e12);
    vec3 _e14 = oklabToRgb(_e13);
    vec3 _e15 = sRGBToP3_(_e14);
    return vec4(_e15, totalWeight_1);
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
    vec4 composed_19_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec2 _e9 = uv;
    vec2 flowCentred_9_ = (_e9 - vec2(0.5));
    float _e17 = _group_0_binding_0_fs._sys.viewportSize.x;
    float _e22 = _group_0_binding_0_fs._sys.viewportSize.y;
    float aspect_10_ = (_e17 / max(_e22, 1e-6));
    float _e29 = _group_0_binding_0_fs.n_n._animTime;
    float flowTime_12_ = (_e29 * 0.075);
    float _e35 = _group_0_binding_0_fs.n_n.seed;
    float flowSeed_13_ = (_e35 * 0.17);
    float flowStrength_14_ = _group_0_binding_0_fs.n_n.distortion;
    float _e55 = noise_mxNoiseFloat3_(vec3(((flowCentred_9_.x * 0.8) + (flowTime_12_ * 0.4)), ((flowCentred_9_.y * 0.8) - (flowTime_12_ * 0.25)), flowSeed_13_));
    float flowAngle_11_ = ((_e55 * 12.566371) * flowStrength_14_);
    vec2 flowSpun_8_ = vec2(((vec2(flowCentred_9_.x, (flowCentred_9_.y / aspect_10_)).x * cos(flowAngle_11_)) - (vec2(flowCentred_9_.x, (flowCentred_9_.y / aspect_10_)).y * sin(flowAngle_11_))), ((vec2(flowCentred_9_.x, (flowCentred_9_.y / aspect_10_)).x * sin(flowAngle_11_)) + (vec2(flowCentred_9_.x, (flowCentred_9_.y / aspect_10_)).y * cos(flowAngle_11_))));
    vec2 flowRot_7_ = vec2(flowSpun_8_.x, (flowSpun_8_.y * aspect_10_));
    float flowShearX_6_ = (flowRot_7_.x + ((sin(((flowRot_7_.y * 5.0) + (flowTime_12_ * 2.0))) / 50.0) * flowStrength_14_));
    vec4 _e129 = chainedWarpStep(vec2(flowShearX_6_, (flowRot_7_.y + ((sin(((flowShearX_6_ * 7.5) + (flowTime_12_ * 2.0))) / 25.0) * flowStrength_14_))), 2.0, ((flowTime_12_ * 0.5) + flowSeed_13_), vec2(5.2, 1.3), vec2(1.7, 9.2), 0.25, flowStrength_14_);
    float flowHardness_4_ = pow(((_e129.z * 0.5) + 0.5), 1.5);
    float flowEdge_3_ = mix(0.5, 0.008, flowHardness_4_);
    float flowTz_16_ = ((flowTime_12_ * 0.3) + flowSeed_13_);
    vec4 _e152 = chainedWarpStep(_e129.xy, 1.5, flowTz_16_, vec2(8.3, 2.8), vec2(3.1, 7.4), 0.2, flowStrength_14_);
    float _e162 = noise_mxNoiseFloat3_(vec3((_e152.x * 1.8), (_e152.y * 1.8), flowTz_16_));
    float flowT1_2_ = smoothstep((flowEdge_3_ * -1.0), flowEdge_3_, _e162);
    vec3 _e167 = _group_0_binding_0_fs.n_n.convA;
    float _e172 = _group_0_binding_0_fs.n_n.colorA.w;
    vec3 _e176 = _group_0_binding_0_fs.n_n.convB;
    float _e181 = _group_0_binding_0_fs.n_n.colorB.w;
    MixStep _e182 = mixInSpace(_e167, _e172, _e176, _e181, flowT1_2_);
    vec3 _e186 = _group_0_binding_0_fs.n_n.convC;
    float _e191 = _group_0_binding_0_fs.n_n.colorC.w;
    vec3 _e195 = _group_0_binding_0_fs.n_n.convD;
    float _e200 = _group_0_binding_0_fs.n_n.colorD.w;
    MixStep _e201 = mixInSpace(_e186, _e191, _e195, _e200, flowT1_2_);
    float flowT2_18_ = smoothstep((flowEdge_3_ * -1.0), flowEdge_3_, _e129.w);
    vec4 _e210 = mixPreconvertedColors(_e182.conv, _e201.conv, _e182.alpha, _e201.alpha, flowT2_18_);
    composed_19_ = vec4(clamp((_e210.xyz * (((((_e152.z * 0.5) + 0.5) * 0.12) + 0.94) * (1.0 + ((max((1.0 - abs(((flowT1_2_ * 2.0) - 1.0))), (1.0 - abs(((flowT2_18_ * 2.0) - 1.0)))) * flowHardness_4_) * 0.35)))), vec3(0.0), vec3(1.0)), _e210.w);
    vec4 _e251 = composed_19_;
    vec3 _e253 = tone_linear(_e251.xyz);
    vec3 _e254 = linearToSrgb(_e253);
    float _e256 = composed_19_.w;
    _fs2p_location0 = vec4(_e254, _e256);
    return;
}

