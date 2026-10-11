uniform sampler2D geometry_data : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : filter_nearest, repeat_disable;
uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform int quad_count = 0;
varying vec3 shade;
varying flat int blend_mode;

bool additive_texel(vec2 uv) {
    return (blend_mode == 2 || blend_mode == 4) && texture(mask_texture, uv).r > 0.5;
}

vec4 geometry(int index) {
    return texelFetch(geometry_data, ivec2(index % 192, index / 192), 0);
}

void vertex() {
    int quad = VERTEX_ID / 4;
    int base = VERTEX_ID * 3;
    vec4 point = geometry(base);
    vec4 uv_color = geometry(base + 1);
    vec4 color_blend = geometry(base + 2);
    VERTEX = quad < quad_count ? point.xyz : vec3(0.0);
    vec3 a = geometry(quad * 12).xyz;
    vec3 b = geometry(quad * 12 + 3).xyz;
    vec3 c = geometry(quad * 12 + 6).xyz;
    vec3 normal = cross(c - a, b - a);
    NORMAL = dot(normal, normal) > 1e-20 ? normalize(normal) : vec3(0.0, 0.0, 1.0);
    UV = uv_color.xy;
    shade = vec3(uv_color.zw, color_blend.x);
    blend_mode = int(color_blend.y);
    vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    view.z += point.w;
    POSITION = PROJECTION_MATRIX * view;
}
