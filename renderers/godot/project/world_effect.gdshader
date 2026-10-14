shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "world_effect_geometry.gdshaderinc"
#include "world_effect_appearance.gdshaderinc"

uniform bool original_lighting = false;

void fragment() {
    if ((surface_flags & 16) != 0 && !FRONT_FACING) discard;
    vec4 texel = effect_sample(UV);
    if (effect_discard(texel, UV)) discard;
    bool emissive = original_lighting || (surface_flags & 8) != 0;
    vec3 display_color = emissive ? clamp(texel.rgb * shade, vec3(0.0), vec3(1.0)) : texel.rgb;
    vec3 linear_color = mix(display_color / 12.92, pow((display_color + 0.055) / 1.055, vec3(2.4)), greaterThan(display_color, vec3(0.04045)));
    if (!emissive) linear_color *= shade;
    linear_color *= effect_tint.rgb;
    // Weight fog by the additive texture's coverage, preserving unfogged RGB.
    float coverage = additive_texel(UV) ? max(max(linear_color.r, linear_color.g), linear_color.b) : 1.0;
    if (coverage <= 0.0) discard;
    linear_color /= coverage;
    ALBEDO = emissive ? vec3(0.0) : linear_color;
    EMISSION = (emissive ? linear_color * emissive_energy : vec3(0.0)) + emission_color.rgb * shade;
    ROUGHNESS = effect_roughness;
    METALLIC = effect_metallic;
    SPECULAR = effect_specular;
    bool semi = blend_mode != 0 && texture(mask_texture, UV).r > 0.5;
    ALPHA = texel.a * (!semi ? 1.0 : (blend_mode == 1 ? 0.5 : 0.0));
    PREMUL_ALPHA_FACTOR = texel.a * coverage * (!semi ? 1.0 : (blend_mode == 1 ? 0.5 : (blend_mode == 4 ? 0.25 : 1.0)));
}
