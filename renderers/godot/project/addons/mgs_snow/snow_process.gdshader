shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec3 volume_size = vec3(12.0, 8.0, 12.0);
uniform vec2 flake_size = vec2(0.012, 0.035);
uniform float fall_speed = 0.8;
uniform float speed_variation = 0.35;
uniform vec3 wind_velocity = vec3(0.15, 0.0, 0.05);
uniform float gust_strength = 0.2;
uniform float gust_speed = 0.7;
uniform float flutter_strength = 0.12;
uniform float flutter_speed = 1.5;
uniform float settle_time = 0.8;
uniform bool prewarm = true;

uint hash(uint value) {
	value = ((value >> 16u) ^ value) * 73244475u;
	value = ((value >> 16u) ^ value) * 73244475u;
	return (value >> 16u) ^ value;
}

float random(inout uint seed) {
	seed = hash(seed);
	return float(seed) / 4294967295.0;
}

void start() {
	uint seed = hash(NUMBER + RANDOM_SEED);
	CUSTOM = vec4(random(seed), 1.0, 0.0, 0.0);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = vec3(random(seed) - 0.5, prewarm ? random(seed) - 0.5 : 0.5, random(seed) - 0.5) * volume_size;
	USERDATA1 = vec4(0.0);
}

void process() {
	USERDATA1.x += DELTA;
	float size = mix(flake_size.x, flake_size.y, CUSTOM.x);
	if (DELTA > 0.0) {
		if (COLLIDED) {
			TRANSFORM[3].xyz += COLLISION_NORMAL * COLLISION_DEPTH;
			vec3 normal = normalize(COLLISION_NORMAL);
			vec3 up = abs(normal.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
			vec3 right = normalize(cross(up, normal));
			TRANSFORM[0].xyz = right;
			TRANSFORM[1].xyz = cross(normal, right);
			TRANSFORM[2].xyz = normal;
			CUSTOM.z = 1.0;
		}
		if (CUSTOM.z > 0.5) {
			CUSTOM.w += DELTA;
			CUSTOM.y = 1.0 - smoothstep(0.0, settle_time, CUSTOM.w);
		} else {
			float phase = CUSTOM.x * 6.28318530718;
			vec3 wind = wind_velocity;
			if (length(wind) > 0.00001) wind += normalize(wind) * sin(USERDATA1.x * gust_speed) * gust_strength;
			vec3 velocity = wind + vec3(sin(USERDATA1.x * flutter_speed + phase), 0.0, cos(USERDATA1.x * flutter_speed * 0.83 + phase * 1.7)) * flutter_strength;
			velocity.y -= fall_speed * mix(1.0 - speed_variation, 1.0 + speed_variation, CUSTOM.x);
			TRANSFORM[3].xyz += velocity * DELTA;
		}
		if (any(greaterThan(abs(TRANSFORM[3].xyz), volume_size * 0.5)) || CUSTOM.w >= settle_time) {
			USERDATA1.y += 1.0;
			uint seed = hash(NUMBER + RANDOM_SEED + uint(USERDATA1.y) * 977u);
			TRANSFORM = mat4(1.0);
			TRANSFORM[3].xyz = vec3(random(seed) - 0.5, 0.5, random(seed) - 0.5) * volume_size;
			CUSTOM.yzw = vec3(1.0, 0.0, 0.0);
		}
		TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz) * size;
		TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz) * size;
		TRANSFORM[2].xyz = normalize(TRANSFORM[2].xyz) * size;
	}
}
