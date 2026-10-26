shader_type canvas_item;
// Screen-space colour grade for the lush, sunlit-forest look:
// soft bloom on bright areas, warm highlights, cool green shade, vignette.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float bloom = 0.14;
uniform float warmth = 0.05;
uniform float shade_tint = 0.10;
uniform float vignette = 0.32;
uniform float saturation = 1.06;
uniform float contrast = 1.06;
uniform float sun_glow = 0.06;
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
// morning haze: soft warm light lifted into the shadows
uniform float haze = 0.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	// cheap bloom: blurred bright parts from a lower mip
	vec3 b = textureLod(screen, SCREEN_UV, 3.0).rgb;
	c += max(b - 0.55, 0.0) * bloom * 1.8;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// split tone: warm sun in the lights, cool green in the shade
	c = mix(c, c * vec3(1.06, 1.0, 0.86), smoothstep(0.45, 0.9, lum) * warmth * 4.0);
	c = mix(c, c * vec3(0.86, 1.0, 1.02), (1.0 - smoothstep(0.1, 0.45, lum)) * shade_tint * 4.0);
	c = mix(vec3(lum), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// sun glow from the top-right corner
	vec2 uv = SCREEN_UV;
	c += glow_color.rgb * sun_glow * smoothstep(1.1, 0.0, distance(uv, vec2(1.05, -0.1)));
	c = mix(c, c + glow_color.rgb * 0.18, haze * (1.0 - smoothstep(0.0, 0.7, lum)));
	float v = smoothstep(0.95, 0.35, distance(uv, vec2(0.5)) * 1.05);
	c *= mix(1.0 - vignette, 1.0, v);
	COLOR = vec4(c, 1.0);
}
