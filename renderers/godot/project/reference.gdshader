shader_type spatial;
render_mode unshaded, fog_disabled;

#include "reference_packet.gdshaderinc"
varying vec4 affine_shade;

void vertex() {
    vec4 shade = texture(shade_texture, UV2);
    face_visible = shade.a;
    UV = texture(packet_texture, UV2).xy;
    float clip_w = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    affine_shade = vec4(shade.rgb * (255.0 / 128.0), 1.0) * clip_w;
}

void fragment() {
    vec4 texel = texture(albedo_texture, UV);
    if (face_visible < 0.5 || texel.a < 0.5) discard;
    vec3 encoded = clamp(texel.rgb * affine_shade.rgb / affine_shade.a, 0.0, 1.0);
    ALBEDO = decode_display_color(encoded);
}
