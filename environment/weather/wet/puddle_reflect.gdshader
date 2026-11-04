shader_type canvas_item;
// upside-down copy of a character / lamp, visible only inside the puddles
#include "res://environment/weather/wet/wet_common.gdshaderinc"
uniform sampler2D ground_tex : filter_nearest;
uniform vec2 ground_size = vec2(1.0);
uniform vec2 ground_pos = vec2(0.0);
uniform float puddles = 0.0;
uniform float rain = 0.0;
uniform float strength = 0.55;
uniform float glow = 0.0;          // lamps: keep the flame bright in the water
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 guv = (world - ground_pos) / ground_size;
	float dirt = wet_dirt(ground_tex, guv, 1.0 / ground_size);
	float pm = wet_puddle(world, puddles, dirt);
	vec3 rp = wet_ripples(world, TIME, rain);
	vec2 uv = UV + vec2(sin(world.y * 0.35 + TIME * 3.0) * 0.6 + rp.y * 2.5, 0.0) * TEXTURE_PIXEL_SIZE;
	vec4 t = texture(TEXTURE, uv);
	float fade = smoothstep(0.15, 1.0, UV.y);              // strongest at the feet, fades towards the head
	vec3 col = mix(t.rgb * vec3(0.62, 0.68, 0.8), t.rgb * 1.2, glow);
	COLOR = vec4(col, t.a * pm * strength * mix(fade, 1.0, glow * 0.5));
}
