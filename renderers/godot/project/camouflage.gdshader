shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, fog_disabled;

uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool has_albedo = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float camouflage_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 native_tint = vec3(1.0);
group_uniforms Appearance;
uniform float distortion : hint_range(0.0, 0.1) = 0.06;
uniform float index_of_refraction : hint_range(1.0, 2.0) = 1.35;
uniform float blur_lod : hint_range(0.0, 4.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.65;
uniform float rim_energy : hint_range(0.0, 2.0) = 0.0;
uniform float rim_power : hint_range(0.1, 8.0) = 3.0;
group_uniforms;

void fragment() {
    vec4 base = base_color * (has_albedo ? texture(albedo_texture, UV) : vec4(1.0));
    if (base.a < 0.5) discard;
    float amount = clamp(camouflage_amount, 0.0, 1.0);
    vec3 surface_normal = normalize(NORMAL);
    vec3 incident = -normalize(VIEW);
    surface_normal = faceforward(surface_normal, incident, surface_normal);
    vec3 direction = refract(incident, surface_normal, 1.0 / index_of_refraction);
    vec3 exit_point = VERTEX + direction * max(-VERTEX.z, 0.001) * distortion * amount;
    vec4 projected = PROJECTION_MATRIX * vec4(exit_point, 1.0);
    vec2 sample_uv = clamp(projected.xy / projected.w * 0.5 + 0.5, vec2(0.0), vec2(1.0));
    vec2 half_texel = 0.5 / vec2(textureSize(scene_depth, 0));
    // Reversed Z: use the nearest depth across the filtered color sample's footprint.
    float depth = max(max(
        textureLod(scene_depth, sample_uv + half_texel, 0.0).r,
        textureLod(scene_depth, sample_uv - half_texel, 0.0).r), max(
        textureLod(scene_depth, sample_uv + vec2(half_texel.x, -half_texel.y), 0.0).r,
        textureLod(scene_depth, sample_uv + vec2(-half_texel.x, half_texel.y), 0.0).r));
    vec4 background = INV_PROJECTION_MATRIX * vec4(sample_uv * 2.0 - 1.0, depth, 1.0);
    // The opaque screen copy also contains foreground objects; never refract those into the cloak.
    if (background.z / background.w > VERTEX.z + 0.001) sample_uv = SCREEN_UV;
    vec3 behind = textureLod(scene_texture, sample_uv, blur_lod).rgb;
    vec3 tint = mix(vec3(1.0), native_tint * tint_color.rgb, tint_strength);
    float rim = pow(1.0 - clamp(dot(surface_normal, normalize(VIEW)), 0.0, 1.0), rim_power);
    ALBEDO = base.rgb * (1.0 - amount);
    EMISSION = (behind * tint + rim * rim_energy * tint) * amount;
    ROUGHNESS = 0.8;
    SPECULAR = 0.0;
    ALPHA = base.a;
}
