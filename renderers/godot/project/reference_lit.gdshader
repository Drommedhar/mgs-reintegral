shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "reference_packet.gdshaderinc"

uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_emission = false;
uniform float pbr_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float pbr_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_scale : hint_range(0.0, 4.0) = 1.0;
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;
uniform float alarm_emission = 0.0;

void vertex() {
    face_visible = texture(shade_texture, UV2).a;
    if (face_visible > 0.5) UV = texture(packet_texture, UV2).xy;
}

void fragment() {
    vec4 texel = texture(albedo_texture, UV);
    if (texel.a < 0.5) discard;
    ALBEDO = decode_display_color(texel.rgb);
    vec3 orm = has_orm ? texture(orm_texture, UV).rgb : vec3(1.0);
    AO = orm.r;
    ROUGHNESS = clamp(orm.g * pbr_roughness, 0.04, 1.0);
    METALLIC = orm.b * pbr_metallic;
    if (has_emission) EMISSION = texture(emission_texture, UV).rgb * emission_energy;
    EMISSION += ALBEDO * alarm_emission;
    if (has_normal) {
        vec3 dp1 = dFdx(VERTEX);
        vec3 dp2 = dFdy(VERTEX);
        vec2 duv1 = dFdx(UV);
        vec2 duv2 = dFdy(UV);
        vec3 t = cross(dp2, NORMAL) * duv1.x + cross(NORMAL, dp1) * duv2.x;
        vec3 b = cross(dp2, NORMAL) * duv1.y + cross(NORMAL, dp1) * duv2.y;
        float scale = inversesqrt(max(max(dot(t, t), dot(b, b)), 0.000001));
        vec3 mapped = texture(normal_texture, UV).rgb * 2.0 - 1.0;
        mapped.xy *= normal_scale;
        NORMAL = normalize(mat3(t * scale, b * scale, NORMAL) * mapped);
    }
}
