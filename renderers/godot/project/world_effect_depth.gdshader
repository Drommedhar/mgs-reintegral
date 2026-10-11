shader_type spatial;
render_mode blend_premul_alpha, depth_draw_always, cull_disabled, unshaded, fog_disabled;
#include "world_effect_geometry.gdshaderinc"

void fragment() {
    vec4 texel = texture(albedo_texture, UV);
    if (texel.a < 0.5) discard;
    if (additive_texel(UV) && max(max(texel.r * shade.r, texel.g * shade.g), texel.b * shade.b) <= 0.0) discard;
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
    PREMUL_ALPHA_FACTOR = 0.0;
}
