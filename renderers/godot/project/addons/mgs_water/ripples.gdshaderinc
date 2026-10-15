uniform int ripple_count = 0;
uniform vec4 ripple_rings[16];
uniform float ripple_widths[16];

vec3 water_ripples(vec2 point, float footprint) {
    vec3 result = vec3(0.0);
    for (int index = 0; index < 16; index++) {
        if (index >= ripple_count) { break; }
        vec4 ring = ripple_rings[index];
        vec2 delta = point - ring.xy;
        float distance = length(delta);
        float width = max(ripple_widths[index], 0.03);
        float offset = distance - ring.z;
        if (abs(offset) > width * 4.0) { continue; }
        float k = 3.14159265 / width;
        float envelope = exp(-offset * offset / (2.0 * width * width));
        float amplitude = ring.w * exp(-k * k * footprint * footprint * 0.5);
        float phase = offset * k;
        result.x += amplitude * envelope * cos(phase);
        float slope = amplitude * envelope * (-k * sin(phase) - offset / (width * width) * cos(phase));
        result.yz += delta / max(distance, 0.001) * slope;
    }
    return result;
}
