shader_type spatial;
render_mode unshaded, fog_disabled;

#include "reference_packet.gdshaderinc"
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform bool quantize_color = true;
varying flat float ordering_depth;

void vertex() {
    vec4 packet = texture(packet_texture, UV2);
    UV = packet.xy;
    ordering_depth = packet.z;
    face_visible = texture(shade_texture, UV2).a;
}

void fragment() {
    if (face_visible < 0.5 || texture(albedo_texture, UV).a < 0.5) discard;
    float mask = step(0.5, texture(mask_texture, UV).r);
    vec3 encoded = vec3(mod(ordering_depth, 256.0), floor(ordering_depth / 256.0),
        mask + (quantize_color ? 2.0 : 0.0)) / 255.0;
    ALBEDO = decode_display_color(encoded);
}
