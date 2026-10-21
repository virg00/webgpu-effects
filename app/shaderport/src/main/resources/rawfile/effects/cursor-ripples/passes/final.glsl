#version 300 es
// Ported from shader-effects-inc/shaders (MIT, (c) 2026 Shader Effects Inc.)
//   source: packages/core/src/shaders/CursorRipples/index.ts @ v4.0.4
//   changes: WGSL -> GLSL ES 3.00 via naga 30.0.1; no manual edits
//   license: MIT (this file) ; Apache-2.0 (project)

precision highp float;
precision highp int;

struct ChromaticSplitUVs {
    vec2 rUV;
    vec2 gUV;
    vec2 bUV;
};
struct padded {
    float _opacity;
    float _pad0_;
    float _pad1_;
    float _pad2_;
};
struct padded_1_ {
    float intensity;
    float decay;
    float radius;
    float chromaticSplit;
    float edges;
    float _opacity;
    float _pad0_;
    float _pad1_;
};
struct struct_1_ {
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
    padded_1_ n_n;
    struct_1_ n_base;
    struct_2_ _sys;
};
struct final_Input {
    vec2 uv;
};
uniform highp sampler2D _group_1_binding_0_fs;

layout(std140) uniform combined_block_0Fragment { combined _group_0_binding_0_fs; };

smooth in vec2 _vs2fs_location0;
layout(location = 0) out vec4 _fs2p_location0;

vec4 unpremultiplyAlpha(vec4 color2_) {
    float alpha = color2_.w;
    vec3 straightRGB = ((alpha > 0.001) ? (color2_.xyz / vec3(alpha)) : vec3(0.0));
    return vec4(straightRGB, alpha);
}

ChromaticSplitUVs chromaticDisplaceUVs(vec2 uv_1, vec2 disp, float strength, float chromaticSplit) {
    vec2 scaled = (disp * (strength * 0.1));
    vec2 clamped = clamp(scaled, vec2(-0.15, -0.15), vec2(0.15, 0.15));
    float chromaticScale = (chromaticSplit * 0.1);
    vec2 rUV = (uv_1 - (clamped * (1.0 + chromaticScale)));
    vec2 gUV = (uv_1 - clamped);
    vec2 bUV = (uv_1 - (clamped * (1.0 - chromaticScale)));
    return ChromaticSplitUVs(rUV, gUV, bUV);
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
    vec2 _e11 = uv;
    float _e18 = _group_0_binding_0_fs.n_n.intensity;
    float _e22 = _group_0_binding_0_fs.n_n.chromaticSplit;
    ChromaticSplitUVs _e23 = chromaticDisplaceUVs(_e11, vec2(0.0, 0.0), _e18, _e22);
    vec4 _e25 = texture(_group_1_binding_0_fs, vec2(_e23.rUV));
    vec2 _e29 = uv;
    float _e36 = _group_0_binding_0_fs.n_n.intensity;
    float _e40 = _group_0_binding_0_fs.n_n.chromaticSplit;
    ChromaticSplitUVs _e41 = chromaticDisplaceUVs(_e29, vec2(0.0, 0.0), _e36, _e40);
    vec4 _e43 = texture(_group_1_binding_0_fs, vec2(_e41.gUV));
    vec2 _e47 = uv;
    float _e54 = _group_0_binding_0_fs.n_n.intensity;
    float _e58 = _group_0_binding_0_fs.n_n.chromaticSplit;
    ChromaticSplitUVs _e59 = chromaticDisplaceUVs(_e47, vec2(0.0, 0.0), _e54, _e58);
    vec4 _e61 = texture(_group_1_binding_0_fs, vec2(_e59.bUV));
    vec2 _e65 = uv;
    float _e72 = _group_0_binding_0_fs.n_n.intensity;
    float _e76 = _group_0_binding_0_fs.n_n.chromaticSplit;
    ChromaticSplitUVs _e77 = chromaticDisplaceUVs(_e65, vec2(0.0, 0.0), _e72, _e76);
    vec4 _e79 = texture(_group_1_binding_0_fs, vec2(_e77.gUV));
    vec4 _e82 = unpremultiplyAlpha(vec4(_e25.x, _e43.y, _e61.z, _e79.w));
    composed_0_ = _e82;
    vec4 _e84 = composed_0_;
    vec3 _e86 = tone_linear(_e84.xyz);
    vec3 _e87 = linearToSrgb(_e86);
    float _e89 = composed_0_.w;
    _fs2p_location0 = vec4(_e87, _e89);
    return;
}

