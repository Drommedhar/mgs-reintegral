shader_type spatial;
render_mode unshaded, fog_disabled;

#include "reference_packet.gdshaderinc"
#include "reference_order.gdshaderinc"
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
varying flat float ordering_depth;

void vertex() {
    POSITION = native_ordered_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
    vec4 live = live_descriptor(UV2);
    live_uv = live.xy;
    live_page = int(live.z) - 1;
    live_clut = int(live.w);
    vec4 packet = texture(packet_texture, UV2);
    UV = packet.xy;
    ordering_depth = packet.z;
    face_visible = texture(shade_texture, UV2).a;
}

void fragment() {
    if (face_visible < 0.5 || reference_texel(UV).a < 0.5) discard;
    float mask = step(0.5, reference_stp(mask_texture, UV));
    vec3 encoded = vec3(mod(ordering_depth, 256.0), floor(ordering_depth / 256.0),
        mask + (quantize_color ? 2.0 : 0.0)) / 255.0;
    ALBEDO = decode_display_color(encoded);
}
