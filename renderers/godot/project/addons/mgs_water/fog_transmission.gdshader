shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

#include "fog.gdshaderinc"

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    ALBEDO = water_fog(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
    ALPHA = 1.0;
}
