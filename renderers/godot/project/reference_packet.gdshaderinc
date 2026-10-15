uniform sampler2D albedo_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D shade_texture : filter_nearest, repeat_disable;
uniform sampler2D packet_texture : filter_nearest, repeat_disable;
uniform bool quantize_color = true;
varying flat float face_visible;
uniform sampler2D live_packet_texture : filter_nearest, repeat_disable;
uniform sampler2D live_vram : filter_nearest, repeat_disable;
uniform bool has_live_texture = false;
varying vec2 live_uv;
varying flat int live_page;
varying flat int live_clut;

vec4 live_descriptor(vec2 uv) {
    if (!has_live_texture) return vec4(0.0);
    return texture(live_packet_texture, uv);
}

uint live_word(ivec2 point) {
    vec4 pixel = texelFetch(live_vram, point & ivec2(1023, 511), 0);
    uvec4 bits = uvec4(round(pixel * vec4(31.0, 31.0, 31.0, 1.0)));
    return bits.r | (bits.g << 5u) | (bits.b << 10u) | (bits.a << 15u);
}

uint live_color() {
    ivec2 point = ivec2(floor(live_uv)) & ivec2(255);
    int depth = (live_page >> 7) & 3;
    if (depth == 3) return 0u;
    ivec2 base = ivec2((live_page & 15) * 64, ((live_page >> 4) & 1) * 256);
    uint word = live_word(base + ivec2(point.x >> (2 - depth), point.y));
    if (depth == 2) return word;
    int shift = depth == 0 ? (point.x & 3) * 4 : (point.x & 1) * 8;
    uint index = (word >> uint(shift)) & (depth == 0 ? 15u : 255u);
    return live_word(ivec2((live_clut & 63) * 16 + int(index), live_clut >> 6));
}

vec4 reference_texel(vec2 uv) {
    if (!has_live_texture || live_page < 0) return texture(albedo_texture, uv);
    uint color = live_color();
    return vec4(vec3(color & 31u, (color >> 5u) & 31u, (color >> 10u) & 31u) / 31.0, color == 0u ? 0.0 : 1.0);
}

float reference_stp(sampler2D mask, vec2 uv) {
    return has_live_texture && live_page >= 0 ? float((live_color() >> 15u) & 1u) : texture(mask, uv).r;
}

vec3 decode_display_color(vec3 encoded) {
    return mix(encoded / 12.92, pow((encoded + 0.055) / 1.055, vec3(2.4)),
        greaterThan(encoded, vec3(0.04045)));
}
