shader_type canvas_item;
// Realistic pixel-art water for rivers and moats.
// The texture is a map of the whole world:
//   R = depth (0 shore .. 1 deep), G = 1 inside the moat, B = shore foam, A = water mask.

uniform vec4 shallow : source_color = vec4(0.30, 0.42, 0.38, 1.0);
uniform vec4 deep : source_color = vec4(0.08, 0.20, 0.27, 1.0);
uniform vec4 moat_tint : source_color = vec4(0.16, 0.30, 0.28, 1.0);
uniform vec4 sky : source_color = vec4(0.95, 0.72, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.92, 0.88, 1.0);
uniform vec2 flow = vec2(0.894, -0.447);   // river runs along its bank
uniform float color_levels = 18.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t, float calm) {
	vec2 q = vec2(dot(p, flow), dot(p, vec2(-flow.y, flow.x)));
	float h = noise(q * vec2(0.035, 0.12) - vec2(t * 0.8 * calm, 0.0)) * 0.55;
	h += noise(q * vec2(0.09, 0.26) - vec2(t * 1.4 * calm, t * 0.2) + 7.0) * 0.3;
	h += noise(q * vec2(0.3, 0.6) + vec2(t * 0.7, -t * 0.4) + 3.0) * 0.15;
	return h;
}
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0)); int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return m[x + y * 4] / 16.0 - 0.5;
}

void fragment() {
	vec4 map = texture(TEXTURE, UV);
	if (map.a < 0.5) discard;
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	float d = map.r;
	float is_moat = step(0.5, map.g);
	float calm = mix(1.0, 0.25, is_moat);
	float t = TIME;

	float h = waves(p, t, calm);
	float hx = waves(p + vec2(1, 0), t, calm) - h;
	float hy = waves(p + vec2(0, 1), t, calm) - h;
	vec3 n = normalize(vec3(-hx * 9.0, -hy * 9.0, 1.0));

	vec3 c = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 1.0, d));
	c = mix(c, moat_tint.rgb * (0.85 + 0.3 * (1.0 - d)), is_moat * 0.7);
	// sky reflection, stronger on open water
	float fres = clamp(0.25 + 0.5 * d + n.y * 1.6, 0.0, 1.0);
	c = mix(c, sky.rgb * 0.62 + deep.rgb * 0.38, fres * mix(0.45, 0.25, is_moat));
	vec3 L = normalize(vec3(0.55, -0.6, 0.55));
	c *= 0.82 + 0.3 * clamp(dot(n, L), 0.0, 1.0);
	// sun glints
	vec3 Hh = normalize(L + vec3(0.0, 0.55, 0.85));
	float spec = pow(max(dot(n, Hh), 0.0), 70.0);
	c += vec3(1.0, 0.86, 0.66) * step(0.8, spec) * smoothstep(0.08, 0.3, d) * 0.5;
	// shore: lighter, sandy shallows + lapping foam
	c = mix(c, vec3(0.42, 0.40, 0.30), (1.0 - smoothstep(0.0, 0.07, d)) * 0.55 * (1.0 - is_moat));
	float fn = noise(vec2(p.x * 0.16 - t * 1.2, p.y * 0.32 + t * 0.5));
	float foam = step(0.55, map.b + (fn - 0.5) * 0.6) * step(0.3, fn);
	c = mix(c, foam_color.rgb, foam * 0.7 * (1.0 - 0.6 * is_moat));
	// lily pads with lotus flowers floating on the moat
	vec2 cell = floor(p / 13.0);
	float hp = hash(cell + 11.3);
	vec2 cc = (cell + 0.5 + (vec2(hash(cell + 2.1), hash(cell + 5.7)) - 0.5) * 0.5) * 13.0;
	vec2 dv = (p - cc) * vec2(1.0, 2.0);
	float pad = step(length(dv), 4.0 + hp * 2.0) * step(0.82, hp) * is_moat;
	c = mix(c, vec3(0.30, 0.50, 0.22) * (0.85 + 0.25 * step(0.0, dv.x)), pad);
	float bloom = pad * step(length(dv - vec2(1.0, -1.0)), 1.3) * step(0.9, hp);
	c = mix(c, vec3(0.95, 0.55, 0.70), bloom);
	// pixel-art finish
	c = floor(c * color_levels + 0.5 + bayer4(p) * 0.6) / color_levels;
	COLOR = vec4(c, 1.0);
}
