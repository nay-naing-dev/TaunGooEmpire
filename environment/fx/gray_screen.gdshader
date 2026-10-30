shader_type canvas_item;
// Greys out and darkens everything drawn under it (behind a modal box).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// 0 = untouched .. 1 = fully grey and dimmed
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float dim : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 grey = vec3(dot(c, vec3(0.299, 0.587, 0.114))) * (1.0 - dim);
	COLOR = vec4(mix(c, grey, amount), 1.0);
}
