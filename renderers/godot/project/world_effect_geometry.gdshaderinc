uniform sampler2D geometry_data : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : filter_nearest, repeat_disable;
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform int quad_count = 0;
uniform bool screen_sized = false;
uniform float beam_width : hint_range(0.0, 16.0) = 1.0;
varying vec3 shade;
varying flat int blend_mode;
varying flat int surface_flags;

bool additive_texel(vec2 uv) {
    return (blend_mode == 2 || blend_mode == 4) && texture(mask_texture, uv).r > 0.5;
}

vec4 geometry(int index) {
    return texelFetch(geometry_data, ivec2(index % 192, index / 192), 0);
}

vec3 effect_point(int base, mat4 local_to_view, mat4 projection, mat3 view_to_local) {
    vec3 point = geometry(base).xyz;
    float depth = -(local_to_view * vec4(point, 1.0)).z;
    vec2 pixel_scale = vec2((4.0 / 3.0) / 320.0, 1.0 / 224.0) *
        (2.0 * max(depth, 0.0) / projection[1][1]);
    if ((int(geometry(base + 2).y) & 32) != 0) {
        int quad = base / 12;
        vec3 a = (local_to_view * vec4(geometry(quad * 12).xyz, 1.0)).xyz;
        vec3 b = (local_to_view * vec4(geometry(quad * 12 + 3).xyz, 1.0)).xyz;
        // Clip only the facing calculation; GPU clipping retains the actual endpoints.
        if (a.z >= -0.001 && b.z >= -0.001) return point;
        if (a.z > -0.001) a = mix(a, b, (-0.001 - a.z) / (b.z - a.z));
        if (b.z > -0.001) b = mix(b, a, (-0.001 - b.z) / (a.z - b.z));
        vec4 clip_a = projection * vec4(a, 1.0);
        vec4 clip_b = projection * vec4(b, 1.0);
        vec2 direction = (clip_b.xy / clip_b.w - clip_a.xy / clip_a.w) *
            vec2(240.0 / projection[0][0], 224.0 / projection[1][1]);
        if (dot(direction, direction) < 1e-12) return point;
        vec2 width = normalize(vec2(-direction.y, direction.x)) * vec2(2.0, 1.0) * beam_width;
        float side = (base / 3) % 4 < 2 ? -0.5 : 0.5;
        return point + view_to_local * vec3(width * pixel_scale * side, 0.0);
    }
    vec2 billboard_offset = geometry(base + 2).zw;
    if (screen_sized) billboard_offset *= pixel_scale;
    return point + view_to_local * vec3(billboard_offset, 0.0);
}

void vertex() {
    int quad = VERTEX_ID / 4;
    int base = VERTEX_ID * 3;
    vec4 point = geometry(base);
    vec4 uv_color = geometry(base + 1);
    vec4 color_blend = geometry(base + 2);
    mat3 view_to_local = inverse(mat3(MODELVIEW_MATRIX));
    VERTEX = quad < quad_count ? effect_point(base, MODELVIEW_MATRIX, PROJECTION_MATRIX, view_to_local) : vec3(0.0);
    vec3 a = effect_point(quad * 12, MODELVIEW_MATRIX, PROJECTION_MATRIX, view_to_local);
    vec3 b = effect_point(quad * 12 + 3, MODELVIEW_MATRIX, PROJECTION_MATRIX, view_to_local);
    vec3 c = effect_point(quad * 12 + 6, MODELVIEW_MATRIX, PROJECTION_MATRIX, view_to_local);
    vec3 normal = cross(c - a, b - a);
    NORMAL = dot(normal, normal) > 1e-20 ? normalize(normal) : vec3(0.0, 0.0, 1.0);
    UV = uv_color.xy;
    shade = vec3(uv_color.zw, color_blend.x);
    blend_mode = int(color_blend.y) & 7;
    surface_flags = int(color_blend.y) & ~7;
    vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    view.z += point.w;
    POSITION = PROJECTION_MATRIX * view;
}
