#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Ring/index.ts @ v4.0.4
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
    vec4 color;
    vec2 center;
    float radius;
    float thickness;
    float softness;
    float strokeThickness;
    vec4 strokeColor;
    float strokePosition;
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
struct ShapeMask {
    float overallMask;
    float strokeBlend;
};
struct final_Input {
    vec2 uv;
};
layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

vec2 shapeLocalCoords(vec2 center, float rotation, vec2 uv_1, float aspect) {
    vec2 aspectUV = vec2((uv_1.x * aspect), uv_1.y);
    vec2 centerPos = vec2((center.x * aspect), (1.0 - center.y));
    float dx_1 = (aspectUV.x - centerPos.x);
    float dy_1 = (aspectUV.y - centerPos.y);
    float rotRad = (rotation * 0.017453292);
    float cosR = cos(rotRad);
    float sinR = sin(rotRad);
    float rdx = ((dx_1 * cosR) + (dy_1 * sinR));
    float rdy = ((dy_1 * cosR) - (dx_1 * sinR));
    return vec2(rdx, rdy);
}

ShapeMask strokeMaskFromSdf(float dist, float softness, float strokeThickness, float strokePosition) {
    bool hasStroke = (strokeThickness > 0.0);
    bool isInside = (strokePosition >= 1.5);
    bool isCenterOrAbove = (strokePosition >= 0.5);
    float halfThickness = (strokeThickness * 0.5);
    float negThickness = (strokeThickness * -1.0);
    float negHalf = (halfThickness * -1.0);
    float strokeInner = (isInside ? negThickness : (isCenterOrAbove ? negHalf : 0.0));
    float strokeOuter = (isInside ? 0.0 : (isCenterOrAbove ? halfThickness : strokeThickness));
    float overallMask = (1.0 - smoothstep((strokeOuter - softness), strokeOuter, dist));
    float blend = smoothstep((strokeInner - softness), strokeInner, dist);
    float strokeBlend = (hasStroke ? blend : 0.0);
    return ShapeMask(overallMask, strokeBlend);
}

float ringSdf(float dx, float dy, float radius, float thickness) {
    float len = sqrt(((dx * dx) + (dy * dy)));
    return (abs((len - radius)) - thickness);
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
    vec4 composed_2_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec2 _e12 = _group_0_binding_0_fs.n_n.center;
    vec2 _e14 = uv;
    float _e18 = _group_0_binding_0_fs._sys.aspect;
    vec2 _e19 = shapeLocalCoords(_e12, 0.0, _e14, _e18);
    float _e25 = _group_0_binding_0_fs.n_n.radius;
    float _e29 = _group_0_binding_0_fs.n_n.thickness;
    float _e30 = ringSdf(_e19.x, _e19.y, _e25, _e29);
    float _e34 = _group_0_binding_0_fs.n_n.softness;
    float _e38 = _group_0_binding_0_fs.n_n.strokeThickness;
    float _e42 = _group_0_binding_0_fs.n_n.strokePosition;
    ShapeMask _e43 = strokeMaskFromSdf(_e30, _e34, _e38, _e42);
    vec4 _e47 = _group_0_binding_0_fs.n_n.color;
    vec4 _e51 = _group_0_binding_0_fs.n_n.strokeColor;
    vec4 _e53 = mixColors(_e47, _e51, _e43.strokeBlend);
    vec4 _e58 = _group_0_binding_0_fs.n_n.color;
    vec4 _e62 = _group_0_binding_0_fs.n_n.strokeColor;
    vec4 _e64 = mixColors(_e58, _e62, _e43.strokeBlend);
    composed_2_ = vec4(_e53.xyz, (_e64.w * _e43.overallMask));
    vec4 _e70 = composed_2_;
    vec3 _e72 = tone_linear(_e70.xyz);
    vec3 _e73 = linearToSrgb(_e72);
    float _e75 = composed_2_.w;
    _fs2p_location0 = vec4(_e73, _e75);
    return;
}

