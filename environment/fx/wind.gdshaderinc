// Shared wind for trees, palms and grass: slow gusts roll across the whole map,
// so a gust you see bending the grass reaches the trees a moment later.
const vec2 WIND_DIR = vec2(0.94, 0.34);

// 0 = calm .. 1 = in the middle of a gust, at world position p.
float wind_gust(vec2 p) {
	float w = dot(p, WIND_DIR) * 0.0042 - TIME * 0.3;
	float g = 0.5 + 0.5 * sin(w * 6.2831853);
	float g2 = 0.5 + 0.5 * sin(w * 2.7 + 1.3);
	return g * g * g * (0.55 + 0.45 * g2);
}
