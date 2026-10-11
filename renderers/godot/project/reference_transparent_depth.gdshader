shader_type spatial;
render_mode blend_premul_alpha, depth_draw_always, unshaded, fog_disabled;
#include "reference_packet.gdshaderinc"

uniform bool original_lighting = false;

void vertex() {
    face_visible = texture(shade_texture, UV2).a;
    if (face_visible > 0.5) UV = texture(packet_texture, UV2).xy;
}

void fragment() {
    if ((original_lighting && face_visible < 0.5) || texture(albedo_texture, UV).a < 0.5) discard;
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
    PREMUL_ALPHA_FACTOR = 0.0;
}
