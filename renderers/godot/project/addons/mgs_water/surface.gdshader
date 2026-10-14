shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

#include "optics.gdshaderinc"
#include "waves.gdshaderinc"
#include "ripples.gdshaderinc"

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 water_inverse;
uniform vec3 volume_size = vec3(8.0, 4.0, 8.0);
uniform vec3 absorption = vec3(0.7, 0.24, 0.15);
uniform vec3 water_color : source_color = vec3(0.015, 0.055, 0.045);
uniform vec3 reflection_fallback : source_color = vec3(0.015, 0.025, 0.03);
uniform float water_time = 0.0;
uniform float wave_height : hint_range(0.0, 1.0) = 0.08;
uniform float wavelength : hint_range(0.1, 50.0) = 3.2;
uniform float wave_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform float geometry_footprint = 0.0;
uniform float roughness : hint_range(0.02, 1.0) = 0.13;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.018;
uniform int reflection_steps : hint_range(0, 64) = 24;
uniform float reflection_distance : hint_range(1.0, 100.0) = 20.0;
uniform float reflection_thickness : hint_range(0.01, 2.0) = 0.25;
uniform float reflection_view_distance : hint_range(1.0, 500.0) = 80.0;
uniform bool use_coverage_mask = false;
uniform sampler2D coverage_mask : repeat_disable, filter_linear_mipmap;
uniform bool invert_coverage_mask = false;
uniform bool virtual_bottom_enabled = false;
uniform sampler2D bottom_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 bottom_color : source_color = vec3(0.3, 0.32, 0.3);
uniform float bottom_depth : hint_range(0.01, 2.0) = 0.12;
uniform vec2 bottom_tile_size = vec2(2.0, 2.0);
varying vec3 water_position;

void vertex() {
    water_position = (water_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float height = water_wave(water_position.xz, water_time * wave_speed, wave_height, wavelength, geometry_footprint).x;
    height += water_ripples(water_position.xz, geometry_footprint).x;
    VERTEX += (inverse(MODEL_MATRIX) * inverse(water_inverse) * vec4(0.0, height, 0.0, 0.0)).xyz;
}

vec4 trace_reflection(vec3 origin, vec3 direction, mat4 projection, mat4 projection_inverse) {
    if (reflection_steps == 0 || length(origin) >= reflection_view_distance) { return vec4(0.0); }
    float previous = 0.0;
    float step_size = reflection_distance / float(reflection_steps);
    for (int step = 0; step < 64; step++) {
        if (step >= reflection_steps) { break; }
        float distance = (float(step) + 1.0) * step_size;
        vec3 point = origin + direction * distance;
        if (point.z >= -0.02) { break; }
        vec2 uv = water_project(point, projection);
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { break; }
        float depth = textureLod(scene_depth, uv, 0.0).r;
        vec3 opaque = water_view_position(uv, depth, projection_inverse);
        float gap = opaque.z - point.z;
        if (depth > 0.000001 && gap >= 0.0) {
            float low = previous;
            float high = distance;
            for (int refine = 0; refine < 5; refine++) {
                float middle = (low + high) * 0.5;
                vec3 sample_point = origin + direction * middle;
                uv = water_project(sample_point, projection);
                opaque = water_view_position(uv, textureLod(scene_depth, uv, 0.0).r, projection_inverse);
                if (opaque.z > sample_point.z) { high = middle; } else { low = middle; }
            }
            point = origin + direction * high;
            uv = water_project(point, projection);
            opaque = water_view_position(uv, textureLod(scene_depth, uv, 0.0).r, projection_inverse);
            gap = opaque.z - point.z;
            float confidence = water_edge_fade(uv) * (1.0 - smoothstep(reflection_thickness * 0.5, reflection_thickness, abs(gap)));
            confidence *= 1.0 - smoothstep(reflection_distance * 0.7, reflection_distance, high);
            confidence *= 1.0 - smoothstep(reflection_view_distance * 0.7, reflection_view_distance, length(origin));
            return vec4(textureLod(scene_color, uv, roughness * 4.0).rgb, confidence);
        }
        previous = distance;
    }
    return vec4(0.0);
}

void fragment() {
    if (use_coverage_mask) {
        float coverage = texture(coverage_mask, UV).a;
        coverage = invert_coverage_mask ? 1.0 - coverage : coverage;
        if (coverage < 0.5) { discard; }
    }
    float footprint = max(length(dFdx(water_position.xz)), length(dFdy(water_position.xz)));
    vec3 wave = water_wave(water_position.xz, water_time * wave_speed, wave_height, wavelength, footprint);
    wave += water_ripples(water_position.xz, footprint);
    vec3 water_normal = normalize(vec3(-wave.y, 1.0, -wave.z));
    vec3 normal = normalize(transpose(mat3(water_inverse * INV_VIEW_MATRIX)) * water_normal);
    NORMAL = FRONT_FACING ? normal : -normal;
    float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
    vec3 opaque = water_view_position(SCREEN_UV, depth, INV_PROJECTION_MATRIX);
    float separation = max(-opaque.z + VERTEX.z, 0.0);
    vec2 refracted_uv = SCREEN_UV + NORMAL.xy * refraction_strength * smoothstep(0.0, 0.4, separation);
    vec3 refracted = water_view_position(refracted_uv, textureLod(scene_depth, refracted_uv, 0.0).r, INV_PROJECTION_MATRIX);
    float guard = water_edge_fade(refracted_uv) * step(refracted.z, VERTEX.z - 0.01);
    refracted_uv = mix(SCREEN_UV, refracted_uv, guard);
    refracted = water_view_position(refracted_uv, textureLod(scene_depth, refracted_uv, 0.0).r, INV_PROJECTION_MATRIX);
    vec3 from = (water_inverse * INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 to = (water_inverse * INV_VIEW_MATRIX * vec4(refracted, 1.0)).xyz;
    float path = water_segment(from, to, volume_size) * length(refracted - VERTEX);
    vec3 transmission = exp(-max(absorption, vec3(0.0)) * path);
    vec3 behind = textureLod(scene_color, refracted_uv, 0.0).rgb;
    if (virtual_bottom_enabled) {
        vec3 camera_local = (water_inverse * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        vec3 ray = refract(normalize(water_position - camera_local), water_normal, 1.0 / 1.333);
        float distance_to_bottom = bottom_depth / max(-ray.y, 0.05);
        vec2 bottom_uv = (water_position.xz + ray.xz * distance_to_bottom) / max(bottom_tile_size, vec2(0.01));
        behind = texture(bottom_texture, bottom_uv).rgb * bottom_color;
        transmission = exp(-max(absorption, vec3(0.0)) * distance_to_bottom);
    }
    float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 5.0);
    vec4 reflected = trace_reflection(VERTEX + NORMAL * 0.025, reflect(-VIEW, NORMAL), PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
    ALBEDO = virtual_bottom_enabled ? behind * transmission * (1.0 - fresnel) : vec3(0.0);
    METALLIC = 0.0;
    SPECULAR = 0.25;
    ROUGHNESS = clamp(roughness + footprint * wave_height * 0.5, 0.02, 1.0);
    RADIANCE = reflected;
    EMISSION = ((virtual_bottom_enabled ? vec3(0.0) : behind * transmission) + water_color * (vec3(1.0) - transmission)) * (1.0 - fresnel);
    EMISSION += reflection_fallback * fresnel * (1.0 - reflected.a);
    ALPHA = 1.0;
}
