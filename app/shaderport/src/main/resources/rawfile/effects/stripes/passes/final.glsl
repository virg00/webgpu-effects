#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Stripes/index.ts @ v4.0.4
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
    float angle;
    float density;
    float balance;
    float softness;
    float speed;
    float offset;
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

float geom_aspectOf(vec2 viewport) {
    return (viewport.x / max(viewport.y, 1e-6));
}

vec2 canvasCentredDelta(vec2 uv_1, float aspect) {
    return vec2(((uv_1.x * aspect) - (aspect * 0.5)), (uv_1.y - 0.5));
}

float directionalProjection(vec2 p, float cosA, float sinA) {
    return ((p.x * cosA) + (p.y * sinA));
}

float stripeCoordP(vec2 uv_2, vec2 viewport_1, float angle, float density, float animTime, float offset) {
    float angleRad = (angle * 0.017453292);
    float _e8 = geom_aspectOf(viewport_1);
    vec2 _e9 = canvasCentredDelta(uv_2, _e8);
    float _e12 = directionalProjection(_e9, cos(angleRad), sin(angleRad));
    float rotatedCoord = (_e12 + (_e8 * 0.5));
    return (((rotatedCoord * density) + animTime) + offset);
}

float footprint1_(float x, float softness) {
    float _e2 = dFdx(x);
    float _e4 = dFdy(x);
    float baseW = max(abs(_e2), abs(_e4));
    return max((baseW + softness), 1e-5);
}

float quilezStepFilter(float p_1, float w, float threshold) {
    float a_1 = (p_1 + (w * 0.5));
    float b_1 = (p_1 - (w * 0.5));
    float oneMinusThreshold = (1.0 - threshold);
    float Fa = ((floor(a_1) * oneMinusThreshold) + max((fract(a_1) - threshold), 0.0));
    float Fb = ((floor(b_1) * oneMinusThreshold) + max((fract(b_1) - threshold), 0.0));
    return clamp(((Fa - Fb) / w), 0.0, 1.0);
}

float stripesMask(vec2 uv_3, vec2 viewport_2, float angle_1, float density_1, float animTime_1, float offset_1, float balance, float softness_1) {
    float _e8 = stripeCoordP(uv_3, viewport_2, angle_1, density_1, animTime_1, offset_1);
    float _e9 = footprint1_(_e8, softness_1);
    float _e10 = quilezStepFilter(_e8, _e9, balance);
    return _e10;
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
    float _e25 = _group_0_binding_0_fs.n_n.angle;
    float _e29 = _group_0_binding_0_fs.n_n.density;
    float _e33 = _group_0_binding_0_fs.n_n._animTime;
    float _e37 = _group_0_binding_0_fs.n_n.offset;
    float _e41 = _group_0_binding_0_fs.n_n.balance;
    float _e45 = _group_0_binding_0_fs.n_n.softness;
    float _e46 = stripesMask(_e17, _e21, _e25, _e29, _e33, _e37, _e41, _e45);
    vec4 _e47 = mixColors(_e12, _e16, _e46);
    composed_0_ = _e47;
    vec4 _e49 = composed_0_;
    vec3 _e51 = tone_linear(_e49.xyz);
    vec3 _e52 = linearToSrgb(_e51);
    float _e54 = composed_0_.w;
    _fs2p_location0 = vec4(_e52, _e54);
    return;
}

