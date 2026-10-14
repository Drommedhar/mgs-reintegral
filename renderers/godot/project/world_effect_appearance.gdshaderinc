group_uniforms Appearance;
uniform vec4 effect_tint : source_color = vec4(1.0);
uniform bool use_custom_texture = false;
uniform sampler2D custom_texture : filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float effect_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float effect_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float effect_specular : hint_range(0.0, 1.0) = 0.0;
uniform float emissive_energy : hint_range(0.0, 16.0) = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float beam_heat : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

vec4 effect_sample(vec2 uv) {
    vec4 texel = use_custom_texture ? texture(custom_texture, uv) : texture(albedo_texture, uv);
    texel.a *= effect_tint.a;
    return texel;
}

bool effect_discard(vec4 texel, vec2 uv) {
    return ((surface_flags & 32) != 0 && max(max(shade.r, shade.g), shade.b) <= 0.0) ||
        texel.a <= 0.0 || texel.a < alpha_cutoff ||
        (additive_texel(uv) && max(max(texel.r * shade.r * effect_tint.r,
        texel.g * shade.g * effect_tint.g), texel.b * shade.b * effect_tint.b) <= 0.0);
}
