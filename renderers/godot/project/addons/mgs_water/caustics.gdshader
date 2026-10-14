shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_disabled, ambient_light_disabled, fog_disabled, specular_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 water_inverse;
uniform vec3 volume_size = vec3(8.0, 4.0, 8.0);
uniform vec3 caustic_color : source_color = vec3(0.65, 0.9, 0.8);
uniform float strength : hint_range(0.0, 3.0) = 0.5;
uniform float pattern_scale : hint_range(0.1, 50.0) = 2.0;
uniform float caustic_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform float water_time = 0.0;
uniform bool diagnostic_flat = false;
varying vec3 receiver_local;
varying vec3 water_up;
varying mat3 view_to_water;
varying float caustic_fade;

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
    if (depth <= 0.000001) { discard; }
    vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    view /= view.w;
    vec3 world = (INV_VIEW_MATRIX * view).xyz;
    receiver_local = (water_inverse * vec4(world, 1.0)).xyz;
    vec3 edge = vec3(volume_size.x * 0.5 - abs(receiver_local.x),
                     min(-receiver_local.y, receiver_local.y + volume_size.y),
                     volume_size.z * 0.5 - abs(receiver_local.z));
    if (min(min(edge.x, edge.y), edge.z) <= 0.0) { discard; }
    LIGHT_VERTEX = view.xyz;
    vec3 normal = normalize(cross(dFdx(view.xyz), dFdy(view.xyz)));
    NORMAL = dot(normal, -view.xyz) < 0.0 ? -normal : normal;
    water_up = normalize((VIEW_MATRIX * inverse(water_inverse) * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    view_to_water = mat3(water_inverse * INV_VIEW_MATRIX);
    caustic_fade = smoothstep(0.0, 0.08, min(min(edge.x, edge.y), edge.z));
    caustic_fade *= exp(receiver_local.y * 0.3) * strength;
    ALBEDO = caustic_color;
    ALPHA = 1.0;
}

void light() {
    float incident = max(dot(NORMAL, LIGHT), 0.0);
    float surface_incident = max(dot(water_up, LIGHT), 0.0);
    vec3 local_light = view_to_water * LIGHT;
    vec2 p = (receiver_local.xz - receiver_local.y * local_light.xz / max(local_light.y, 0.05)) * pattern_scale;
    float seconds = water_time * caustic_speed;
    vec2 wave = sin(p * 0.61 + vec2(seconds * 0.37, -seconds * 0.29));
    float field = sin(p.x + wave.y * 2.1) + cos(p.y + wave.x * 1.7);
    field += 0.35 * sin(dot(p, vec2(1.31, 0.79)) - seconds * 0.43);
    float width = max(fwidth(field), 0.03);
    float caustic = (1.0 - smoothstep(0.02, 0.12 + width, abs(field))) * 0.12 / (0.12 + width);
    caustic = diagnostic_flat ? 1.0 : caustic;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * incident * surface_incident * caustic * caustic_fade / PI;
}
