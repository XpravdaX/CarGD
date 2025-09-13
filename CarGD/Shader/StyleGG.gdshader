shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 luminosity_weights = vec3(0.299, 0.587, 0.114);

void fragment() {
    vec4 texture_color = texture(albedo_texture, UV);

    float luminosity = dot(texture_color.rgb, luminosity_weights);
    vec3 adjusted_color = mix(vec3(luminosity), texture_color.rgb, saturation);
    adjusted_color = (adjusted_color * brightness - 0.5) * contrast + 0.5;

    float vignette = UV.x * UV.y * (1.0 - UV.x) * (1.0 - UV.y);
    vignette = clamp(vignette * 4.0, 0.0, 1.0);
    adjusted_color *= mix(1.0, vignette, vignette_strength);

    adjusted_color *= tint_color.rgb;

    ALBEDO = clamp(adjusted_color, vec3(0.0), vec3(1.0));
}
