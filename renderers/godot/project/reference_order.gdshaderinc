instance uniform float native_depth_bias = 0.0;

vec4 native_ordered_position(vec3 vertex, mat4 model_view, mat4 projection) {
    vec4 view = model_view * vec4(vertex, 1.0);
    vec4 clip = projection * view;
    if (!IN_SHADOW_PASS && native_depth_bias != 0.0) {
        view.z += native_depth_bias;
        vec4 ordered = projection * view;
        clip.z = ordered.z / ordered.w * clip.w;
    }
    return clip;
}
