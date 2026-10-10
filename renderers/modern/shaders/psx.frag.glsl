// SPDX-License-Identifier: MPL-2.0
#version 450

layout(location = 0) noperspective in vec4 vertexColor;
layout(location = 1) in vec2 rawUV;
layout(location = 2) flat in uint tpage;
layout(location = 3) flat in uint clut;
layout(location = 4) flat in uint textureMode;
layout(location = 5) flat in uint subPixelMask;
layout(location = 6) flat in uint texelShift;
layout(location = 7) flat in uint indexShift;
layout(location = 8) flat in uint indexMask;
layout(location = 9) flat in uint dither;
layout(location = 10) flat in ivec2 pageBase;
layout(location = 11) flat in uvec4 texWindow;
layout(location = 12) flat in uint polygon;

layout(set = 2, binding = 0) uniform sampler2D texVram;
layout(set = 2, binding = 1) uniform sampler2D texFramebuffer;

vec4 readVram(ivec2 position) {
    return texelFetch(texVram, position & ivec2(1023, 511), 0);
}

layout(set = 3, binding = 0) uniform FragmentParams {
    uint forceMask;
    uint preserveMasked;
    float renderScale;
    uint samplingFlags;
};

uvec2 resolveTexel() {
    float bias = (samplingFlags & 2u) != 0u ? 0.5 / renderScale : 0.5;
    vec2 uv = rawUV + (polygon != 0u ? vec2(bias) : vec2(0.0));
    uvec2 texel = uvec2(ivec2(floor(uv))) & uvec2(255u);
    return (texel & texWindow.xy) | texWindow.zw;
}



vec4 readFramebuffer() {
    vec2 uv = rawUV + (polygon != 0u ? vec2(0.5 / renderScale) : vec2(0.0));
    uvec2 whole = uvec2(ivec2(floor(uv))) & uvec2(255u);
    whole = (whole & texWindow.xy) | texWindow.zw;
    ivec2 address = (pageBase + ivec2(whole)) & ivec2(1023, 511);
    ivec2 samplePosition = ivec2(vec2(address) * renderScale + floor(fract(uv) * renderScale));
    return texelFetch(texFramebuffer, samplePosition, 0);
}

layout(location = 0) out vec4 FragColor;

uint rgb5551ToU16(vec4 c) {
    uint r = uint(c.r * 31.0 + 0.5);
    uint g = uint(c.g * 31.0 + 0.5);
    uint b = uint(c.b * 31.0 + 0.5);
    uint a = uint(c.a + 0.5);
    return r | (g << 5u) | (b << 10u) | (a << 15u);
}

const mat4 ditherMatrix = mat4(
    -4.0, +0.0, -3.0, +1.0,
    +2.0, -2.0, +3.0, -1.0,
    -3.0, +1.0, -4.0, +0.0,
    +3.0, -1.0, +2.0, -2.0);
vec3 applyDither(vec3 c) {
    if (dither == 0u) return c;
    int dx = int(gl_FragCoord.x) & 3;
    int dy = int(gl_FragCoord.y) & 3;
    float off = ditherMatrix[dy][dx];
    vec3 c8 = c * 255.0 + off;
    vec3 c5 = clamp(floor(c8 / 8.0), 0.0, 31.0);
    return c5 / 31.0;
}

void main() {
    vec4 texColor;
    if (textureMode == 0u) { // untextured
        texColor = vec4(1, 1, 1, 0);
    } else if (textureMode == 1u) { // 16-bit bitmap
        texColor = (samplingFlags & 1u) != 0u ? readFramebuffer()
                                           : readVram(pageBase + ivec2(resolveTexel()));
    } else { // indexed
        ivec2 texel = ivec2(resolveTexel());
        uint subPixel = uint(texel.x) & subPixelMask;
        ivec2 texelPos = ivec2(texel.x >> texelShift, texel.y);
        uint word16 = rgb5551ToU16(readVram(pageBase + texelPos));
        uint colorIdx = (word16 >> (subPixel * indexShift)) & indexMask;
        ivec2 clutBase = ivec2((clut % 64u) * 16u, clut / 64u);
        texColor = readVram(clutBase + ivec2(colorIdx, 0));
    }
    // check for full transparency
    if (texColor == vec4(0, 0, 0, 0)) {
        discard;
    }
    // check for setSemiTrans(p, 1)
    bool isSemiTrans = vertexColor.a < 0.75;
    // when a color has the 0x8000 bit left then it has the semitrans flag on
    bool colorSemiTrans = textureMode == 0u || texColor.a > 0.5;
    // PS1-accurate texture-color modulation: (tex5 * col8) >> 7, clamp to 31
    vec3 modColor;
    if (textureMode == 0u) {
        // untextured: PS1 uses color directly, no modulation
        modColor = dither != 0u ? vertexColor.rgb
                               : floor(vertexColor.rgb * 255.0 / 8.0) / 31.0;
    } else {
        vec3 tex5 = floor(texColor.rgb * 31.0 + 0.5);
        vec3 col8 = min(floor(vertexColor.rgb * 127.5 + 0.5), vec3(255.0));
        vec3 prod8 = min(tex5 * col8 / 16.0, vec3(255.0));
        modColor = dither != 0u ? prod8 / 255.0
                                : floor(prod8 / 8.0) / 31.0;
    }
    modColor = applyDither(modColor);
    vec4 destination = (samplingFlags & 4u) != 0u
        ? texelFetch(texFramebuffer, ivec2(gl_FragCoord.xy), 0)
        : texelFetch(texVram, ivec2(gl_FragCoord.xy / renderScale), 0);
    if (preserveMasked != 0u && destination.a > 0.5) {
        discard;
    }
    ivec3 foreground = ivec3(floor(modColor * 31.0 + 0.5));
    if (colorSemiTrans && isSemiTrans) {
        ivec3 background = ivec3(floor(destination.rgb * 31.0 + 0.5));
        uint abr = (tpage & 0x60u) >> 5u;
        if (abr == 0u) {
            foreground = (background + foreground) / 2;
        } else if (abr == 1u) {
            foreground = background + foreground;
        } else if (abr == 2u) {
            foreground = background - foreground;
        } else {
            foreground = background + foreground / 4;
        }
    }
    float mask = forceMask != 0u || texColor.a > 0.5 ? 1.0 : 0.0;
    FragColor = vec4(vec3(clamp(foreground, 0, 31)) / 31.0, mask);
}
