shader_type spatial;
render_mode blend_premul_alpha, depth_draw_always, unshaded, fog_disabled;
#include "reference_packet.gdshaderinc"
#include "reference_order.gdshaderinc"

uniform bool original_lighting = false;

void vertex() {
    POSITION = native_ordered_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
    vec4 live = live_descriptor(UV2);
    live_uv = live.xy;
    live_page = int(live.z) - 1;
    live_clut = int(live.w);
    face_visible = texture(shade_texture, UV2).a;
    if (face_visible > 0.0) UV = texture(packet_texture, UV2).xy;
}

void fragment() {
    if ((original_lighting && face_visible == 0.0) || reference_texel(UV).a < 0.5) discard;
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
    PREMUL_ALPHA_FACTOR = 0.0;
}
