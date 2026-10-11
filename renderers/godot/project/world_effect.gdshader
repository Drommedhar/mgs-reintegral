shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "world_effect_geometry.gdshaderinc"

uniform bool original_lighting = false;

void fragment() {
    vec4 texel = texture(albedo_texture, UV);
    if (texel.a < 0.5) discard;
    vec3 display_color = original_lighting ? clamp(texel.rgb * shade, vec3(0.0), vec3(1.0)) : texel.rgb;
    vec3 linear_color = mix(display_color / 12.92, pow((display_color + 0.055) / 1.055, vec3(2.4)), greaterThan(display_color, vec3(0.04045)));
    if (!original_lighting) linear_color *= shade;
    // Weight fog by the additive texture's coverage, preserving unfogged RGB.
    float coverage = additive_texel(UV) ? max(max(linear_color.r, linear_color.g), linear_color.b) : 1.0;
    if (coverage <= 0.0) discard;
    linear_color /= coverage;
    ALBEDO = original_lighting ? vec3(0.0) : linear_color;
    EMISSION = original_lighting ? linear_color : vec3(0.0);
    ROUGHNESS = 0.8;
    SPECULAR = 0.0;
    bool semi = blend_mode != 0 && texture(mask_texture, UV).r > 0.5;
    ALPHA = !semi ? 1.0 : (blend_mode == 1 ? 0.5 : 0.0);
    PREMUL_ALPHA_FACTOR = coverage * (!semi ? 1.0 : (blend_mode == 1 ? 0.5 : (blend_mode == 4 ? 0.25 : 1.0)));
}
