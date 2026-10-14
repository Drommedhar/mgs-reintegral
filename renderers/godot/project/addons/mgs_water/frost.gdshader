shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D coverage_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D underlying_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_underlying_normal = false;
uniform vec3 frost_color : source_color = vec3(0.72, 0.8, 0.84);
uniform float coverage : hint_range(0.0, 1.0) = 0.24;
uniform float exposure : hint_range(0.0, 1.0) = 0.75;
uniform float patch_scale : hint_range(0.1, 20.0) = 2.0;
uniform float crystal_scale : hint_range(4.0, 2000.0) = 280.0;
uniform float crystal_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3 exposure_up = vec3(0.0, 1.0, 0.0);
uniform bool exposure_in_model_space = false;
uniform float submerged_height = -1.5;
uniform bool exclude_submerged = true;
varying vec3 world_point;
varying vec3 world_normal;
varying vec3 frost_up;

float frost_hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float frost_noise(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(frost_hash(cell), frost_hash(cell + vec3(1,0,0)), f.x),
                   mix(frost_hash(cell + vec3(0,1,0)), frost_hash(cell + vec3(1,1,0)), f.x), f.y),
               mix(mix(frost_hash(cell + vec3(0,0,1)), frost_hash(cell + vec3(1,0,1)), f.x),
                   mix(frost_hash(cell + vec3(0,1,1)), frost_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    frost_up = exposure_in_model_space ? normalize(mat3(MODEL_MATRIX) * exposure_up) : normalize(exposure_up);
}

void fragment() {
    vec3 up = normalize(frost_up);
    float exposed = mix(1.0, smoothstep(-0.1, 0.8, dot(normalize(world_normal), up)), exposure);
    vec3 patch = world_point * patch_scale;
    float noise = frost_noise(patch) * 0.65 + frost_noise(patch * 4.1) * 0.25 + frost_noise(patch * 15.7) * 0.1;
    float mask = texture(coverage_mask, UV).r;
    float frost = smoothstep(1.0 - coverage, 1.15 - coverage, noise) * exposed * mask;
    if (exclude_submerged) { frost *= smoothstep(submerged_height, submerged_height + 0.2, dot(world_point, up)); }
    float footprint = max(length(dFdx(world_point)), length(dFdy(world_point))) * crystal_scale;
    if (frost <= 0.0001) { discard; }
    float resolved = 1.0 - smoothstep(0.2, 0.85, footprint);
    vec3 cell = floor(world_point * crystal_scale);
    vec3 facet = normalize(vec3(frost_hash(cell) - 0.5, frost_hash(cell + 5.0) - 0.5, frost_hash(cell + 13.0) - 0.5));
    vec3 facet_view = (VIEW_MATRIX * vec4(facet, 0.0)).xyz;
    NORMAL = normalize(NORMAL + facet_view * crystal_strength * resolved);
    if (use_underlying_normal) { NORMAL_MAP = texture(underlying_normal, UV).rgb; NORMAL_MAP_DEPTH = 0.35; }
    ALBEDO = frost_color;
    METALLIC = 0.0;
    SPECULAR = 0.45;
    ROUGHNESS = mix(0.46, 0.18, resolved * crystal_strength);
    ALPHA = frost * 0.35;
}
