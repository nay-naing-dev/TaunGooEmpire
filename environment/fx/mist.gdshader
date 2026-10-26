shader_type canvas_item;
// Soft morning mist drifting over the land (fixed to the world, not the screen).
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.82, 1.0);
uniform vec2 cam_pos = vec2(0.0);       // world position of the screen's top-left corner
uniform float zoom = 1.0;
uniform float density = 0.22;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	if (amount <= 0.001) discard;
	vec2 world = cam_pos + FRAGCOORD.xy / zoom;
	vec2 p = world * vec2(0.006, 0.012) + vec2(TIME * 0.025, TIME * 0.008);
	float f = fbm(p) * 0.7 + fbm(p * 2.3 - vec2(TIME * 0.04, 0.0)) * 0.3;
	float m = smoothstep(0.45, 0.85, f);
	COLOR = vec4(tint.rgb, m * density * amount);
}
