// shared by the wet ground and the puddle reflections, so both agree where the puddles are
global uniform sampler2D world_water;
global uniform vec4 world_water_rect;

float wet_hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float wet_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wet_hash(i), wet_hash(i + vec2(1, 0)), u.x), mix(wet_hash(i + vec2(0, 1)), wet_hash(i + vec2(1, 1)), u.x), u.y);
}
float wet_fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * wet_noise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }

// how much this spot is bare earth / path / stone (puddles) rather than grass
float wet_dirt(sampler2D ground, vec2 guv, vec2 gpx) {
	vec3 a = texture(ground, guv).rgb;
	a += texture(ground, guv + gpx * vec2(7.0, 0.0)).rgb;
	a += texture(ground, guv - gpx * vec2(7.0, 0.0)).rgb;
	a += texture(ground, guv + gpx * vec2(0.0, 5.0)).rgb;
	a += texture(ground, guv - gpx * vec2(0.0, 5.0)).rgb;
	a *= 0.2;
	// grass / leaves are green or yellow-green (green above blue, about as high as red);
	// earth is browner (red above green), paving and stone are grey
	float grass = smoothstep(0.03, 0.08, a.g - a.b) * smoothstep(-0.06, 0.0, a.g - a.r);
	return 1.0 - grass;
}

float wet_on_water(vec2 w) {
	vec2 wuv = (w - world_water_rect.xy) / max(world_water_rect.zw, vec2(1.0));
	if (wuv.x < 0.0 || wuv.y < 0.0 || wuv.x > 1.0 || wuv.y > 1.0) return 0.0;
	return smoothstep(0.2, 0.5, texture(world_water, wuv).r);
}

// puddle coverage 0..1 at world position w; level 0 = none, 1 = after a long downpour
float wet_puddle(vec2 w, float level, float dirt) {
	vec2 q = w * vec2(1.0, 1.7);                       // puddles are flatter seen at this angle
	float n = wet_fbm(q * 0.011) * 0.7 + wet_fbm(q * 0.04 + 7.0) * 0.3;
	float th = mix(0.86, 0.56, level);
	float m = smoothstep(th, th + 0.025, n) * step(0.02, level);
	return m * smoothstep(0.35, 0.75, dirt) * (1.0 - wet_on_water(w));
}

// rain rings on the puddle: returns (ring brightness, ring slope x, ring slope y)
vec3 wet_ripples(vec2 w, float t, float rain) {
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		vec2 cell_size = vec2(26.0, 16.0) * (1.0 + float(k) * 0.6);
		vec2 p = w / cell_size + float(k) * 3.7;
		vec2 id = floor(p);
		vec2 f = fract(p) - 0.5;
		vec2 c = vec2(wet_hash(id), wet_hash(id + 5.3)) - 0.5;
		float ph = fract(t * (0.9 + wet_hash(id + 2.1) * 0.6) + wet_hash(id + 9.7));
		vec2 d = (f - c * 0.6) * vec2(1.0, 1.6);
		float r = length(d);
		float rad = ph * 0.45;
		float ring = (1.0 - smoothstep(0.0, 0.05, abs(r - rad))) * (1.0 - ph) * step(wet_hash(id + 1.7), rain);
		acc += vec3(ring, normalize(d + 1e-4) * ring);
	}
	return acc;
}
