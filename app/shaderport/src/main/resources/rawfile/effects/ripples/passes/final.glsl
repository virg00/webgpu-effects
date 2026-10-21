#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Ripples/index.ts @ v4.0.4
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
    vec2 center;
    vec4 colorA;
    vec4 colorB;
    float speed;
    float frequency;
    float softness;
    float thickness;
    float phase;
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

float ripplesMask(vec2 center, float frequency, float softness, float thickness, float phase, float animTime, vec2 uv_1, vec2 viewport) {
    float aspect = (viewport.x / viewport.y);
    float dx = ((uv_1.x * aspect) - (center.x * aspect));
    float dy = (uv_1.y - (1.0 - center.y));
    float dist = length(vec2(dx, dy));
    float waveInput = (((dist * frequency) - animTime) + phase);
    float baseWave = sin(waveInput);
    float thicknessThreshold = ((thickness * 2.0) - 1.0);
    float banded = smoothstep((thicknessThreshold - softness), (thicknessThreshold + softness), baseWave);
    return (1.0 - banded);
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
    vec4 _e12 = _group_0_binding_0_fs.n_n.colorB;
    vec4 _e16 = _group_0_binding_0_fs.n_n.colorA;
    vec2 _e20 = _group_0_binding_0_fs.n_n.center;
    float _e24 = _group_0_binding_0_fs.n_n.frequency;
    float _e28 = _group_0_binding_0_fs.n_n.softness;
    float _e32 = _group_0_binding_0_fs.n_n.thickness;
    float _e36 = _group_0_binding_0_fs.n_n.phase;
    float _e40 = _group_0_binding_0_fs.n_n._animTime;
    vec2 _e41 = uv;
    vec2 _e45 = _group_0_binding_0_fs._sys.viewportSize;
    float _e46 = ripplesMask(_e20, _e24, _e28, _e32, _e36, _e40, _e41, _e45);
    vec4 _e47 = mixColors(_e12, _e16, _e46);
    composed_0_ = _e47;
    vec4 _e49 = composed_0_;
    vec3 _e51 = tone_linear(_e49.xyz);
    vec3 _e52 = linearToSrgb(_e51);
    float _e54 = composed_0_.w;
    _fs2p_location0 = vec4(_e52, _e54);
    return;
}

