shader_type spatial;
render_mode blend_premul_alpha, depth_draw_always, cull_disabled, unshaded, fog_disabled;
#include "world_effect_geometry.gdshaderinc"
#include "world_effect_appearance.gdshaderinc"
uniform bool thermal_pass = false;

void fragment() {
    if ((surface_flags & 16) != 0 && !FRONT_FACING) discard;
    vec4 texel = effect_sample(UV);
    if (effect_discard(texel, UV)) discard;
    if (thermal_pass && ((surface_flags & 32) == 0 || beam_heat <= 0.0)) discard;
    ALBEDO = thermal_pass ? vec3(beam_heat * clamp(max(max(shade.r, shade.g), shade.b), 0.0, 1.0) * texel.a) : vec3(0.0);
    ALPHA = thermal_pass ? 1.0 : 0.0;
    PREMUL_ALPHA_FACTOR = thermal_pass ? 1.0 : 0.0;
}
