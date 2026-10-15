shader_type spatial;
render_mode blend_sub, depth_draw_never, cull_disabled, unshaded, fog_disabled;
#include "world_effect_geometry.gdshaderinc"
#include "world_effect_appearance.gdshaderinc"

void fragment() {
    vec4 texel = effect_sample(UV);
    if (effect_discard(texel, UV)) discard;
    vec3 color = texel.rgb * effect_tint.rgb;
    vec3 linear_color = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)),
        greaterThan(color, vec3(0.04045)));
    ALBEDO = linear_color * shade;
    ALPHA = texel.a;
}
