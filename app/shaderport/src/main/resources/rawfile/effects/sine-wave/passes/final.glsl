#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/SineWave/index.ts @ v4.0.4
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
    float amplitude;
    float frequency;
    float speed;
    float angle;
    vec2 position;
    float thickness;
    float softness;
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

vec2 aspectCenteredDelta(vec2 uv_1, vec2 center, vec2 viewport) {
    float aspect = (viewport.x / max(viewport.y, 1e-6));
    return vec2(((uv_1.x * aspect) - (center.x * aspect)), (uv_1.y - (1.0 - center.y)));
}

vec2 rotate2_(vec2 p, float cosA, float sinA) {
    return vec2(((p.x * cosA) - (p.y * sinA)), ((p.x * sinA) + (p.y * cosA)));
}

float sineWaveMask(vec2 uv_2, vec2 viewport_1, float angle, vec2 position, float frequency, float amplitude, float thickness, float softness, float animTime) {
    vec2 _e9 = aspectCenteredDelta(uv_2, position, viewport_1);
    float angleRad = (angle * 0.017453292);
    float cosAngle = cos(angleRad);
    float sinAngle = sin(angleRad);
    vec2 _e14 = rotate2_(_e9, cosAngle, sinAngle);
    float waveInput = (((_e14.x * frequency) * 6.2831855) + animTime);
    float sineWave = (sin(waveInput) * amplitude);
    float distanceFromWave = abs((_e14.y - sineWave));
    float halfThickness = (thickness * 0.5);
    float halfSoftness = (softness * 0.5);
    return (1.0 - smoothstep((halfThickness - halfSoftness), (halfThickness + halfSoftness), distanceFromWave));
}

vec3 linearToSrgb(vec3 color) {
    vec3 a = ((pow(color, vec3(0.41666)) * 1.055) - vec3(0.055));
    vec3 b = (color * 12.92);
    bvec3 factor = lessThanEqual(color, vec3(0.0031308));
    return mix(a, b, factor);
}

vec3 tone_linear(vec3 color_1) {
    return vec3(color_1.x, color_1.y, color_1.z);
}

void main() {
    final_Input in_ = final_Input(_vs2fs_location0);
    vec2 uv = vec2(0.0);
    vec4 composed_0_ = vec4(0.0);
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec4 _e12 = _group_0_binding_0_fs.n_n.color;
    float _e18 = _group_0_binding_0_fs.n_n.color.w;
    vec2 _e19 = uv;
    vec2 _e23 = _group_0_binding_0_fs._sys.viewportSize;
    float _e27 = _group_0_binding_0_fs.n_n.angle;
    vec2 _e31 = _group_0_binding_0_fs.n_n.position;
    float _e35 = _group_0_binding_0_fs.n_n.frequency;
    float _e39 = _group_0_binding_0_fs.n_n.amplitude;
    float _e43 = _group_0_binding_0_fs.n_n.thickness;
    float _e47 = _group_0_binding_0_fs.n_n.softness;
    float _e51 = _group_0_binding_0_fs.n_n._animTime;
    float _e52 = sineWaveMask(_e19, _e23, _e27, _e31, _e35, _e39, _e43, _e47, _e51);
    composed_0_ = vec4(_e12.xyz, (_e18 * _e52));
    vec4 _e56 = composed_0_;
    vec3 _e58 = tone_linear(_e56.xyz);
    vec3 _e59 = linearToSrgb(_e58);
    float _e61 = composed_0_.w;
    _fs2p_location0 = vec4(_e59, _e61);
    return;
}

