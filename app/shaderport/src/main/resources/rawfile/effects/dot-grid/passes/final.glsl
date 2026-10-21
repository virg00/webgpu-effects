#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/DotGrid/index.ts @ v4.0.4
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
    float density;
    float dotSize;
    float offset;
    float speed;
    float speedVariance;
    float twinkle;
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
struct CellTile {
    vec2 cell;
    vec2 local;
};
struct final_Input {
    vec2 uv;
};
layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

vec2 aspectCorrectedUVFlipY(vec2 uv_1, vec2 viewport) {
    float aspect = (viewport.x / max(viewport.y, 1e-6));
    return vec2((uv_1.x * aspect), (1.0 - uv_1.y));
}

float rowSpeedHash(float row) {
    return fract((sin((row * 127.1)) * 43758.547));
}

float rowSpeedMultiplier(float rowHash, float variance) {
    return (1.0 + (((rowHash - 0.5) * 4.0) * variance));
}

float flooredMod1_(float x, float m) {
    return (x - (m * floor((x / m))));
}

CellTile squareTiling(vec2 p) {
    return CellTile(floor(p), fract(p));
}

float discCoverage(float dist, float radius, float footprint) {
    return (1.0 - smoothstep((radius - (footprint * 0.5)), radius, dist));
}

float dotGridAlpha(vec2 uv_2, vec2 viewport_1, float density, float dotSize, float offset, float speedVariance, float twinkle, float animTime, float time) {
    vec2 _e9 = aspectCorrectedUVFlipY(uv_2, viewport_1);
    vec2 gridUV = (_e9 * density);
    float rowIndex = floor(gridUV.y);
    float _e13 = rowSpeedHash(rowIndex);
    float _e14 = rowSpeedMultiplier(_e13, speedVariance);
    float drift = (animTime * _e14);
    float _e17 = flooredMod1_(rowIndex, 2.0);
    float staticStagger = (offset * _e17);
    vec2 shiftedGrid = vec2(((gridUV.x - staticStagger) - drift), gridUV.y);
    CellTile _e24 = squareTiling(shiftedGrid);
    float centerDistance = length((_e24.local - vec2(0.5)));
    vec2 _e31 = fwidth((_e9 * density));
    float pixelSize = length(_e31);
    float _e35 = discCoverage(centerDistance, (dotSize * 0.5), pixelSize);
    float dotPhase = fract((sin(((_e24.cell.x * 12.9898) + (_e24.cell.y * 78.233))) * 43758.547));
    float twinkleTime = ((time * 2.0) + (dotPhase * 6.2831855));
    float twinkleValue = ((sin(twinkleTime) * 0.5) + 0.5);
    float twinkleModifier = mix(1.0, twinkleValue, twinkle);
    return (_e35 * twinkleModifier);
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
    vec2 _e14 = uv;
    vec2 _e18 = _group_0_binding_0_fs._sys.viewportSize;
    float _e22 = _group_0_binding_0_fs.n_n.density;
    float _e26 = _group_0_binding_0_fs.n_n.dotSize;
    float _e30 = _group_0_binding_0_fs.n_n.offset;
    float _e34 = _group_0_binding_0_fs.n_n.speedVariance;
    float _e38 = _group_0_binding_0_fs.n_n.twinkle;
    float _e42 = _group_0_binding_0_fs.n_n._animTime;
    float _e46 = _group_0_binding_0_fs._sys.time;
    float _e47 = dotGridAlpha(_e14, _e18, _e22, _e26, _e30, _e34, _e38, _e42, _e46);
    composed_0_ = vec4(_e12.xyz, _e47);
    vec4 _e50 = composed_0_;
    vec3 _e52 = tone_linear(_e50.xyz);
    vec3 _e53 = linearToSrgb(_e52);
    float _e55 = composed_0_.w;
    _fs2p_location0 = vec4(_e53, _e55);
    return;
}

