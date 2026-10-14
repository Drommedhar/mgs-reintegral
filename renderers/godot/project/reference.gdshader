shader_type spatial;
render_mode unshaded, fog_disabled;

#include "reference_packet.gdshaderinc"
#include "reference_order.gdshaderinc"
varying vec4 affine_shade;

void vertex() {
    POSITION = native_ordered_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
    vec4 live = live_descriptor(UV2);
    live_uv = live.xy;
    live_page = int(live.z) - 1;
    live_clut = int(live.w);
    vec4 shade = texture(shade_texture, UV2);
    face_visible = shade.a;
    if (face_visible > 0.0) UV = texture(packet_texture, UV2).xy;
    float clip_w = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    affine_shade = vec4(shade.rgb * (255.0 / 128.0), 1.0) * clip_w;
}

void fragment() {
    vec4 texel = reference_texel(UV);
    if ((!IN_SHADOW_PASS && face_visible == 0.0) || texel.a < 0.5) discard;
    vec3 shade = affine_shade.rgb / affine_shade.a;
    vec3 encoded = clamp(texel.rgb * shade, 0.0, 1.0);
    if (quantize_color) {
        vec3 tex5 = floor(texel.rgb * 31.0 + 0.5);
        vec3 col8 = min(floor(shade * 128.0 + 0.5), vec3(255.0));
        encoded = min(tex5 * col8 / 16.0, vec3(255.0)) / 255.0;
    }
    ALBEDO = decode_display_color(encoded);
}
