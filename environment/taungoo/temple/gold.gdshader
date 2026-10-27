shader_type canvas_item;
// Polished gold: sky reflection, sun / torch / lightning highlights, a slow glint
// that sweeps across the temple, and tiny sparkles on the brightest edges.

uniform sampler2D gold_mask : filter_linear;       // white = gold, black = not shiny
uniform float sunlight = 1.0;                      // set by golden_temple.gd (day 1, night/storm low)
uniform vec4 sky_high : source_color = vec4(1.0, 0.95, 0.80, 1.0);
uniform vec4 sky_low : source_color = vec4(0.62, 0.66, 0.78, 1.0);
uniform float sky_reflection = 0.22;
uniform float glint_strength = 0.55;
uniform float glint_every = 7.0;                   // seconds between sweeps
uniform float sparkle = 0.9;
uniform float spec_power = 28.0;
uniform float spec_strength = 1.1;

varying float gold;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 nt = texture(NORMAL_TEXTURE, UV).rgb;
	NORMAL_MAP = nt;
	gold = texture(gold_mask, UV).r;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// faces pointing up reflect the bright sky, the rest the bluish horizon
	vec3 env = mix(sky_low.rgb, sky_high.rgb, clamp(nt.g * 1.4 - 0.2, 0.0, 1.0));
	float k = mix(0.25, 1.0, sunlight);
	c.rgb = mix(c.rgb, c.rgb * env * 1.45, gold * sky_reflection * k);
	// glint: a soft diagonal band of light that sweeps over the temple
	float t = mod(TIME, glint_every) / glint_every;
	float d = (UV.x * 0.7 + (1.0 - UV.y)) - (t * 3.4 - 0.7);
	float band = exp(-d * d / 0.004) + 0.35 * exp(-d * d / 0.03);
	c.rgb += vec3(1.0, 0.9, 0.62) * band * gold * glint_strength * smoothstep(0.3, 0.75, lum) * k;
	// sparkles on bright carved edges
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE / 3.0);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float tw = pow(max(0.0, sin(TIME * 1.7 + h * 80.0)), 60.0);
	c.rgb += vec3(1.0, 0.97, 0.86) * tw * step(0.9, h) * gold * sparkle * smoothstep(0.55, 0.85, lum) * (0.3 + 0.7 * k);
	COLOR = c * COLOR;
}

void light() {
	float nl = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	vec3 H = normalize(LIGHT_DIRECTION + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(NORMAL, H), 0.0), spec_power) * spec_strength * gold;
	vec3 tint = vec3(1.0, 0.86, 0.58);
	// gold keeps its own colour: lights are de-saturated a little on it
	vec3 l = mix(LIGHT_COLOR.rgb, vec3(dot(LIGHT_COLOR.rgb, vec3(0.333))), 0.45 * gold) * LIGHT_ENERGY;
	LIGHT = vec4(COLOR.rgb * l * (0.35 + 0.8 * nl) + l * spec * tint, LIGHT_COLOR.a);
}
