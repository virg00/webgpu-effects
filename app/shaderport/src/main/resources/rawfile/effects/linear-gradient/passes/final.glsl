#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/LinearGradient/index.ts @ v4.0.4
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
    vec2 start;
    vec2 end;
    float angle;
    float edges;
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

float gradientClamp01_(float t_1) {
    return clamp(t_1, 0.0, 1.0);
}

vec2 unflipPosition(vec2 p) {
    return vec2(p.x, (1.0 - p.y));
}

vec2 rotate2_(vec2 p_1, float cosA, float sinA) {
    return vec2(((p_1.x * cosA) - (p_1.y * sinA)), ((p_1.x * sinA) + (p_1.y * cosA)));
}

float gradientRawT(vec2 start, vec2 end, float angle, vec2 uv_1, vec2 viewport) {
    vec2 _e5 = unflipPosition(start);
    vec2 _e6 = unflipPosition(end);
    vec2 gradientVector = (_e6 - _e5);
    float gradientLength = length(gradientVector);
    vec2 gradientDir = normalize(gradientVector);
    float safeViewportY = max(viewport.y, 1e-6);
    float aspect = (viewport.x / safeViewportY);
    float angleRad = ((angle * 0.017453292) * -1.0);
    float cosAngle = cos(angleRad);
    float sinAngle = sin(angleRad);
    vec2 midpoint = ((_e5 + _e6) * 0.5);
    vec2 centeredUV = (uv_1 - midpoint);
    vec2 _e29 = rotate2_(vec2((centeredUV.x * aspect), centeredUV.y), cosAngle, sinAngle);
    vec2 rotatedUV = (vec2((_e29.x / aspect), _e29.y) + midpoint);
    vec2 relativePos = (rotatedUV - _e5);
    float projection = dot(relativePos, gradientDir);
    return (projection / max(gradientLength, 1e-6));
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
    vec2 _e20 = _group_0_binding_0_fs.n_n.start;
    vec2 _e24 = _group_0_binding_0_fs.n_n.end;
    float _e28 = _group_0_binding_0_fs.n_n.angle;
    vec2 _e29 = uv;
    vec2 _e33 = _group_0_binding_0_fs._sys.viewportSize;
    float _e34 = gradientRawT(_e20, _e24, _e28, _e29, _e33);
    float _e35 = gradientClamp01_(_e34);
    float _e36 = gradientClamp01_(_e35);
    vec4 _e37 = mixColors(_e12, _e16, _e36);
    composed_0_ = _e37;
    vec4 _e39 = composed_0_;
    vec3 _e41 = tone_linear(_e39.xyz);
    vec3 _e42 = linearToSrgb(_e41);
    float _e44 = composed_0_.w;
    _fs2p_location0 = vec4(_e42, _e44);
    return;
}

