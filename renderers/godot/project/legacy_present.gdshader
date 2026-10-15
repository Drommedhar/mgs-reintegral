shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform vec4 source_region;
void fragment() {
	vec2 source = source_region.xy * TEXTURE_PIXEL_SIZE + (source_region.zw * TEXTURE_PIXEL_SIZE) * UV;
	COLOR = vec4(texture(TEXTURE, source).rgb, 1.0);
}
