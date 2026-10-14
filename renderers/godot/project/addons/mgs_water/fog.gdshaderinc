#include "optics.gdshaderinc"

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 water_inverse;
uniform vec3 volume_size = vec3(8.0, 4.0, 8.0);
uniform vec3 absorption = vec3(0.7, 0.24, 0.15);
uniform vec3 water_color : source_color = vec3(0.015, 0.055, 0.045);

vec3 water_fog(vec2 uv, mat4 projection_inverse, mat4 view_inverse) {
    vec3 camera = (water_inverse * view_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    if (abs(camera.x) > volume_size.x * 0.5 || abs(camera.z) > volume_size.z * 0.5 || camera.y > 0.0 || camera.y < -volume_size.y) {
        return vec3(1.0);
    }
    vec3 opaque = water_view_position(uv, textureLod(scene_depth, uv, 0.0).r, projection_inverse);
    vec3 endpoint = (water_inverse * view_inverse * vec4(opaque, 1.0)).xyz;
    float path = water_segment(camera, endpoint, volume_size) * length(opaque);
    return exp(-max(absorption, vec3(0.0)) * path);
}
