shader_type canvas_item;
// Clear nature pool: see-through water over a sand-and-pebble bottom, dancing caustic light,
// soft refraction, sky reflection, sun glints, a bright wet shoreline, and koi fish.
// TEXTURE = pool_map.png (R = depth, A = water).

uniform sampler2D bottom : filter_nearest;
uniform vec4 shallow_tint : source_color = vec4(0.62, 0.86, 0.80, 1.0);
uniform vec4 deep_color : source_color = vec4(0.10, 0.38, 0.40, 1.0);
uniform vec4 sky : source_color = vec4(0.84, 0.90, 0.95, 1.0);
uniform float clarity = 0.92;          // 1 = crystal clear, 0 = murky
uniform float caustics = 0.55;
uniform float sky_reflection = 0.22;
uniform int koi_count = 4;
uniform float koi_speed = 0.12;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return noise(p * vec2(0.09, 0.16) + vec2(t * 0.35, t * 0.2)) * 0.6
		+ noise(p * vec2(0.22, 0.4) - vec2(t * 0.55, -t * 0.3) + 4.0) * 0.4;
}
// caustic web: bright where two moving noise fields meet
float caustic(vec2 p, float t) {
	float a = noise(p * 0.11 + vec2(t * 0.25, t * 0.13));
	float b = noise(p * 0.11 * 1.37 - vec2(t * 0.19, -t * 0.22) + 9.0);
	float c = 1.0 - abs(a - b) * 4.0;
	return pow(clamp(c, 0.0, 1.0), 6.0);
}

void fragment() {
	vec4 map = texture(TEXTURE, UV);
	if (map.a < 0.5) discard;
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV / px);
	float d = map.r;
	float t = TIME;
	float h = waves(p, t);
	float hx = waves(p + vec2(1, 0), t) - h;
	float hy = waves(p + vec2(0, 1), t) - h;
	vec3 n = normalize(vec3(-hx * 7.0, -hy * 7.0, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;

	// the bottom, seen through moving water
	vec2 buv = UV + n.xy * px * (1.0 + 3.0 * d);
	vec3 bot = texture(bottom, buv).rgb;
	bot *= 1.0 + caustic(p + n.xy * 6.0, t) * caustics * (1.0 - d * 0.7);

	// koi swimming lazy loops under the surface
	float fish_a = 0.0;
	vec3 fish_c = vec3(0.0);
	for (int i = 0; i < koi_count; i++) {
		float fi = float(i);
		float a = t * koi_speed * (1.0 + 0.3 * fi) + fi * 1.9;
		vec2 c = vec2(0.5, 0.48) + vec2(cos(a) * (0.22 + 0.06 * sin(fi * 2.0)), sin(a * 1.3 + fi) * 0.17);
		vec2 v = normalize(vec2(-sin(a) * 0.22, cos(a * 1.3 + fi) * 0.17 * 1.3) + 1e-4);
		vec2 q = (UV - c) / px;
		vec2 lq = vec2(dot(q, v), dot(q, vec2(-v.y, v.x)));
		float body = step((lq.x / 5.0) * (lq.x / 5.0) + (lq.y / 1.8) * (lq.y / 1.8), 1.0);
		float tail = step(-8.5, lq.x) * step(lq.x, -4.0) * step(abs(lq.y + sin(t * 9.0 + fi) * 0.8), (-lq.x - 4.0) * 0.55);
		float fish = max(body, tail);
		vec3 kc = mod(fi, 2.0) < 1.0 ? vec3(0.98, 0.45, 0.12) : vec3(0.98, 0.92, 0.88);
		if (mod(fi, 3.0) > 1.5 && lq.x > 1.0) kc = vec3(0.95, 0.30, 0.10);
		fish_c = mix(fish_c, kc, fish);
		fish_a = max(fish_a, fish);
	}

	// absorption: shallow = clear aqua over the bottom, deep = blue-green
	float k = smoothstep(0.0, 1.0, d) * (1.15 - clarity * 0.6);
	vec3 c = mix(bot * shallow_tint.rgb * 1.1, deep_color.rgb, clamp(k, 0.0, 0.92));
	c = mix(c, fish_c * mix(vec3(1.0), shallow_tint.rgb, 0.4), fish_a * 0.85 * (1.0 - 0.5 * k));
	// sky reflection (more on deep water) and sun glints
	float fres = clamp(0.12 + 0.6 * d + n.y * 1.2, 0.0, 1.0) * sky_reflection;
	c = mix(c, sky.rgb, fres);
	vec3 L = normalize(vec3(0.55, -0.6, 0.55));
	vec3 Hh = normalize(L + vec3(0.0, 0.55, 0.85));
	float spec = pow(max(dot(n, Hh), 0.0), 90.0);
	c += vec3(1.0, 0.95, 0.85) * smoothstep(0.88, 0.97, spec) * 0.35;
	// bright wet shoreline with gentle lapping
	float lap = 0.5 + 0.5 * sin(t * 1.6 + p.x * 0.05 + p.y * 0.08);
	c = mix(c, vec3(0.92, 0.97, 0.98), (1.0 - smoothstep(0.0, 0.035 + 0.02 * lap, d)) * 0.55);
	COLOR = vec4(c, 1.0);
}
