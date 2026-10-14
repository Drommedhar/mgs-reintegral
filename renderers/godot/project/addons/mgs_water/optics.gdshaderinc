vec3 water_view_position(vec2 uv, float depth, mat4 projection_inverse) {
    vec4 position = projection_inverse * vec4(uv * 2.0 - 1.0, depth, 1.0);
    return position.xyz / position.w;
}

vec2 water_project(vec3 position, mat4 projection) {
    vec4 clip = projection * vec4(position, 1.0);
    return clip.xy / clip.w * 0.5 + 0.5;
}

float water_segment(vec3 from, vec3 to, vec3 size) {
    vec3 direction = to - from;
    vec3 inverse_direction = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), direction)) / max(abs(direction), vec3(0.000001));
    vec3 first = (vec3(-size.x * 0.5, -size.y, -size.z * 0.5) - from) * inverse_direction;
    vec3 last = (vec3(size.x * 0.5, 0.0, size.z * 0.5) - from) * inverse_direction;
    vec3 lower = min(first, last);
    vec3 upper = max(first, last);
    float enter = max(max(lower.x, lower.y), lower.z);
    float leave = min(min(upper.x, upper.y), upper.z);
    return max(min(leave, 1.0) - max(enter, 0.0), 0.0);
}

float water_edge_fade(vec2 uv) {
    vec2 edge = min(uv, vec2(1.0) - uv);
    return smoothstep(0.0, 0.08, min(edge.x, edge.y));
}
