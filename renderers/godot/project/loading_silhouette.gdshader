shader_type canvas_item;

uniform int animation_frame = 0;
uniform sampler2D animation_atlas : filter_nearest, repeat_disable;

float occupied(vec2 cell) {
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, vec2(80.0, 70.0)))) return 0.0;
	vec2 origin = vec2(float(animation_frame % 8) * 80.0, float(animation_frame / 8) * 70.0);
	vec4 pixel = texture(animation_atlas, (origin + cell + 0.5) / vec2(640.0, 350.0));
	float background = distance(pixel.rgb, vec3(160.0, 159.0, 153.0) / 255.0);
	float shadow = distance(pixel.rgb, vec3(111.0) / 255.0);
	return step(0.5, pixel.a) * step(0.002, background) * step(0.002, shadow);
}

void fragment() {
	vec2 cell = floor(UV * vec2(80.0, 70.0));
	float inside = occupied(cell);
	float surrounded = min(min(occupied(cell + vec2(1.0, 0.0)), occupied(cell - vec2(1.0, 0.0))),
		min(occupied(cell + vec2(0.0, 1.0)), occupied(cell - vec2(0.0, 1.0))));
	COLOR = vec4(vec3(0.8), inside * (1.0 - surrounded));
}
