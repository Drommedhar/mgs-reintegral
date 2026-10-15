vec3 water_wave(vec2 point, float time, float amplitude, float wavelength, float footprint) {
    vec3 result = vec3(0.0);
    for (int band = 0; band < 4; band++) {
        float index = float(band);
        float angle = index * 2.399963 + 0.3;
        vec2 direction = vec2(cos(angle), sin(angle));
        float k = 6.2831853 / (wavelength * pow(0.47, index));
        float weight = exp(-k * k * footprint * footprint * 0.5);
        float height = amplitude * pow(0.38, index) * weight;
        float phase = dot(point, direction) * k - time * sqrt(9.81 * k);
        result.x += height * sin(phase);
        result.yz += height * k * cos(phase) * direction;
    }
    return result;
}
