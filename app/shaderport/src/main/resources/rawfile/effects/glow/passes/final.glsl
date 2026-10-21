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
struct final_Input {
    vec2 uv;
};
layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

uniform highp sampler2D _group_1_binding_0_fs;

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

vec4 unpremultiplyAlpha(vec4 color2_) {
    float alpha = color2_.w;
    vec3 straightRGB = ((alpha > 0.001) ? (color2_.xyz / vec3(alpha)) : vec3(0.0));
    return vec4(straightRGB, alpha);
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
    float phony = _group_0_binding_0_fs._sys.time;
    uv = vec2(in_.uv.x, (1.0 - in_.uv.y));
    vec2 _e15 = uv;
    vec4 _e16 = texture(_group_1_binding_0_fs, vec2(_e15));
    vec4 _e17 = unpremultiplyAlpha(_e16);
    composed_0_ = _e17;
    vec4 _e19 = composed_0_;
    vec3 _e21 = tone_linear(_e19.xyz);
    vec3 _e22 = linearToSrgb(_e21);
    float _e24 = composed_0_.w;
    _fs2p_location0 = vec4(_e22, _e24);
    return;
}

