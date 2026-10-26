shader_type canvas_item;
render_mode unshaded;
// Upside-down reflection of a character or boat, only where there is water,
// broken up by small waves and fading away from the feet.

global uniform sampler2D world_water : filter_nearest;
global uniform vec4 world_water_rect;

uniform float strength : hint_range(0.0, 1.0) = 0.62;
uniform vec4 tint : source_color = vec4(0.45, 0.6, 0.68, 1.0);
uniform float fade_px = 70.0;
uniform float wobble = 1.6;

varying vec2 wp;
varying vec2 origin;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

void fragment() {
	vec2 wuv = (wp - world_water_rect.xy) / world_water_rect.zw;
	if (wuv.x < 0.0 || wuv.y < 0.0 || wuv.x > 1.0 || wuv.y > 1.0) discard;   // outside the map
	vec4 w = texture(world_water, wuv);
	if (w.a < 0.5) discard;
	float dist = max(wp.y - origin.y, 0.0);
	float band = floor(wp.y / 2.0);                       // pixel-art wave bands
	float wob = sin(band * 1.1 + TIME * 3.0) * 0.7 + sin(band * 0.37 - TIME * 1.9) * 0.6;
	wob *= wobble * (0.35 + dist / fade_px);
	vec4 c = texture(TEXTURE, UV + vec2(round(wob) * TEXTURE_PIXEL_SIZE.x, 0.0));
	c.rgb = c.rgb * 0.7 * tint.rgb + tint.rgb * 0.1;
	float gaps = 0.7 + 0.3 * step(0.0, sin(band * 2.3 + TIME * 2.2 + wp.x * 0.07));
	c.a *= strength * gaps * (1.0 - smoothstep(0.0, fade_px, dist)) * smoothstep(0.0, 0.05, w.r + 0.02);
	COLOR = c;
}
