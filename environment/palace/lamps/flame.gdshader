shader_type canvas_item;
render_mode unshaded;
// Living flame: the painted flame sways, stretches and breathes.
// wobble = 0 -> no motion (lantern glass), 1 -> open fire.
uniform float wobble = 1.0;
uniform float rim_v = 0.3;      // texture v of the bowl rim (flame base)
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 7.13;
	float up = clamp((rim_v - uv.y) / max(rim_v, 0.001), 0.0, 1.0);   // 0 at rim, 1 at tip
	float sway = sin(t * 5.3 + uv.y * 38.0) * 0.6 + sin(t * 8.7 + uv.y * 61.0) * 0.4;
	uv.x += sway * 0.018 * up * up * wobble;
	float stretch = 1.0 + (sin(t * 6.1) * 0.5 + sin(t * 13.7) * 0.5) * 0.07 * wobble;
	uv.y = rim_v + (uv.y - rim_v) / stretch;
	vec4 c = texture(TEXTURE, uv);
	float heat = smoothstep(0.5, 1.0, max(c.r, c.g));
	c.rgb *= 1.0 + heat * (0.15 + 0.15 * sin(t * 17.0)) * wobble;
	COLOR = c * COLOR;
}
