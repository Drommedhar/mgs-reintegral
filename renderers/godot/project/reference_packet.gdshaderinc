uniform sampler2D albedo_texture : filter_nearest, repeat_disable;
uniform sampler2D shade_texture : filter_nearest, repeat_disable;
uniform sampler2D packet_texture : filter_nearest, repeat_disable;
uniform bool quantize_color = true;
varying flat float face_visible;

vec3 decode_display_color(vec3 encoded) {
    return mix(encoded / 12.92, pow((encoded + 0.055) / 1.055, vec3(2.4)),
        greaterThan(encoded, vec3(0.04045)));
}
