shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 flake_color : source_color = vec4(0.9, 0.95, 1.0, 0.85);
uniform float snow_time = 0.0;
varying float opacity;
varying float shape_seed;

void vertex() {
    opacity = INSTANCE_CUSTOM.y;
    shape_seed = INSTANCE_CUSTOM.x;
    if (INSTANCE_CUSTOM.z < 0.5) {
        float angle = snow_time * (0.8 + shape_seed) + shape_seed * 6.283185;
        float c = cos(angle);
        float s = sin(angle);
        vec3 right = INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz);
        vec3 up = INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz);
        float tumble = 0.55 + 0.45 * abs(sin(angle * 1.3));
        mat4 billboard = mat4(vec4(right * c + up * s, 0.0), vec4((up * c - right * s) * tumble, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
        MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
        MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
    }
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float edge = max(fwidth(radius), 0.06);
    float arms = pow(abs(cos(atan(p.y, p.x) * 3.0)), 10.0);
    float body = mix(0.42, 0.92, arms) * (0.85 + shape_seed * 0.15);
    float coverage = 1.0 - smoothstep(body - edge, body + edge, radius);
    ALBEDO = flake_color.rgb;
    ROUGHNESS = 0.8;
    SPECULAR = 0.25;
    ALPHA = coverage * flake_color.a * opacity;
}
