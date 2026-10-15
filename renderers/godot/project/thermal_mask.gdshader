shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform float heat : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	ALBEDO = vec3(heat * (0.65 + 0.35 * abs(dot(normalize(NORMAL), normalize(VIEW)))));
}
