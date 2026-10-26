shader_type canvas_item;
// Falling rain streaks over the screen, in three depths (near drops are bigger and faster).
// cam_pos makes the rain move with the world when the camera moves.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 cam_pos = vec2(0.0);
uniform vec4 drop_color : source_color = vec4(0.78, 0.84, 0.96, 0.55);
uniform float slant = 0.2;
uniform float speed = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float rain_layer(vec2 px, float cell, float fall, float len, float width, float density, float seed) {
	vec2 p = px;
	p.x += p.y * slant;
	p.y -= TIME * fall * speed;
	vec2 c = vec2(cell, cell * 6.0);
	vec2 id = floor(p / c);
	vec2 f = p - id * c;
	if (hash(id + seed) > density * amount) return 0.0;
	float x0 = (0.15 + 0.7 * hash(id + seed + 1.3)) * c.x;
	float y0 = hash(id + seed + 2.7) * (c.y - len);
	float t = (f.y - y0) / len;
	if (t < 0.0 || t > 1.0) return 0.0;
	float dx = abs(f.x - x0);
	return (1.0 - smoothstep(width * 0.5, width * 0.5 + 0.7, dx)) * (0.25 + 0.75 * t);
}

void fragment() {
	vec2 px = UV * rect_size;
	float r = 0.0;
	r += rain_layer(px + cam_pos * 1.15, 30.0, 1500.0, 46.0, 1.3, 0.34, 0.0);
	r += rain_layer(px + cam_pos, 19.0, 1150.0, 30.0, 0.95, 0.40, 7.0) * 0.7;
	r += rain_layer(px + cam_pos * 0.85, 12.0, 850.0, 18.0, 0.7, 0.45, 13.0) * 0.45;
	COLOR = vec4(drop_color.rgb, clamp(r, 0.0, 1.0) * drop_color.a);
}
