shader_type canvas_item;
// Specular map for the map's ground: soaked earth is glossy, puddles are mirrors.
// Rendered by WetGround into a small viewport and plugged into the ground's CanvasTexture,
// so lamps, torches, fires and the sun leave real highlights on the wet ground.
#include "res://environment/weather/wet/wet_common.gdshaderinc"
uniform sampler2D ground_tex : filter_linear;
uniform vec2 ground_size = vec2(1.0);
uniform vec2 ground_pos = vec2(0.0);
uniform float wet = 0.0;
uniform float puddles = 0.0;

void fragment() {
	vec2 w = ground_pos + UV * ground_size;
	float dirt = wet_dirt(ground_tex, UV, 1.0 / ground_size);
	float pm = wet_puddle(w, puddles, dirt);
	float v = clamp(wet * mix(0.2, 0.45, dirt) + pm * 1.0, 0.0, 1.0);
	COLOR = vec4(vec3(v), 1.0);
}
