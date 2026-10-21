#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/Spiral/index.ts @ v4.0.4
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
    float strokeWidth;
    float strokeFalloff;
    float softness;
    float speed;
    vec2 center;
    float scale;
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

float spiralOffset(vec2 center, float scale, float animTime, vec2 uv_1, vec2 viewport) {
    float aspect = (viewport.x / viewport.y);
    float dx = ((uv_1.x * aspect) - (center.x * aspect));
    float dy = (uv_1.y - (1.0 - center.y));
    float l = length(vec2(dx, dy));
    float angle = (atan(dy, dx) - animTime);
    return ((l * scale) + (angle / 6.2831855));
}

float spiralMask(vec2 center_1, float scale_1, float strokeWidth, float strokeFalloff, float softness, float animTime_1, vec2 uv_2, vec2 viewport_1) {
    float aspect_1 = (viewport_1.x / viewport_1.y);
    float dx_1 = ((uv_2.x * aspect_1) - (center_1.x * aspect_1));
    float dy_1 = (uv_2.y - (1.0 - center_1.y));
    float l_1 = length(vec2(dx_1, dy_1));
    float _e23 = spiralOffset(center_1, scale_1, animTime_1, uv_2, viewport_1);
    float stripe = fract(_e23);
    float shape = (abs((stripe - 0.5)) * 2.0);
    float baseWidth = clamp(strokeWidth, (strokeFalloff * 0.005), 1.0);
    float falloffAmount = (1.0 - (clamp(strokeFalloff, 0.0, 1.0) * l_1));
    float width = (baseWidth * falloffAmount);
    float fw = fwidth(_e23);
    float fwMult = (4.0 - ((smoothstep(0.05, 0.4, (strokeWidth * 2.0)) * smoothstep(0.05, 0.4, ((1.0 - strokeWidth) * 2.0))) * 3.0));
    float _e60 = fwidth(shape);
    float pixelSize = mix((fwMult * fw), _e60, clamp(fw, 0.0, 1.0));
    return smoothstep(((width - pixelSize) - softness), ((width + pixelSize) + softness), shape);
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
    vec2 _e20 = _group_0_binding_0_fs.n_n.center;
    float _e24 = _group_0_binding_0_fs.n_n.scale;
    float _e28 = _group_0_binding_0_fs.n_n.strokeWidth;
    float _e32 = _group_0_binding_0_fs.n_n.strokeFalloff;
    float _e36 = _group_0_binding_0_fs.n_n.softness;
    float _e40 = _group_0_binding_0_fs.n_n._animTime;
    vec2 _e41 = uv;
    vec2 _e45 = _group_0_binding_0_fs._sys.viewportSize;
    float _e46 = spiralMask(_e20, _e24, _e28, _e32, _e36, _e40, _e41, _e45);
    vec4 _e47 = mixColors(_e12, _e16, _e46);
    composed_0_ = _e47;
    vec4 _e49 = composed_0_;
    vec3 _e51 = tone_linear(_e49.xyz);
    vec3 _e52 = linearToSrgb(_e51);
    float _e54 = composed_0_.w;
    _fs2p_location0 = vec4(_e52, _e54);
    return;
}

