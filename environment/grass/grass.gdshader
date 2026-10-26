shader_type canvas_item;
// Smooth vector grass. Every leaf is real geometry, so each one bends on its own:
// idle sway, rolling wind gusts, fluttering tips, and pushed aside by characters.
#include "res://environment/fx/wind.gdshaderinc"

global uniform sampler2D world_shade : filter_linear;
global uniform vec4 world_shade_rect;

uniform float tuft_height = 20.0;      // rough leaf length, used to find each tuft's root
uniform float speed = 1.6;
uniform float sway = 1.6;              // idle sway at the tips (pixels)
uniform float gust_lean = 4.0;         // extra lean in a gust
uniform float flutter = 0.8;           // quick tip flutter
uniform float bend = 12.0;             // how far grass is pushed by characters
uniform vec3 bend_a = vec3(0.0);       // x, y, radius (set by GrassField)
uniform vec3 bend_b = vec3(0.0);
uniform float patchiness = 0.10;       // big soft patches of lighter / darker grass
uniform float shade_strength : hint_range(0.0, 1.0) = 0.75;
uniform bool is_shadow = false;
uniform vec4 shadow_color : source_color = vec4(0.02, 0.06, 0.04, 0.30);

global uniform vec2 shadow_dir;

varying vec2 root;
varying float sun_vis;

float push(vec3 b, vec2 r) {
	if (b.z <= 0.0) return 0.0;
	vec2 d = r - b.xy;
	d.y *= 2.0;
	return (1.0 - smoothstep(b.z * 0.25, b.z, length(d))) * (d.x >= 0.0 ? 1.0 : -1.0);
}

void vertex() {
	float top = 1.0 - UV.y;
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	root = is_shadow ? wp - shadow_dir * top * tuft_height : wp + vec2(0.0, top * tuft_height);
	float g = wind_gust(root);
	float ph = UV.x * 6.2831853 + root.x * 0.07 + root.y * 0.045;
	float p = push(bend_a, root) + push(bend_b, root);
	float d = (sin(TIME * speed + ph) * sway * (0.5 + g) + g * gust_lean + p * bend) * pow(top, 1.6)
		+ sin(TIME * speed * 2.9 + ph * 2.0) * flutter * (0.4 + g) * top * top * top;
	VERTEX.x += d;
	VERTEX.y += abs(d) * 0.3 * top;
	if (!is_shadow) {
		COLOR.rgb *= 1.0 + patchiness * sin(root.x * 0.013 + 1.7) * sin(root.y * 0.021 + 0.4);
	}
}

void fragment() {
	if (is_shadow) {
		COLOR = shadow_color;
	} else {
		float lit = texture(world_shade, (root - world_shade_rect.xy) / world_shade_rect.zw).r;
		sun_vis = mix(1.0, lit, shade_strength);
	}
}

void light() {
	float vis = LIGHT_IS_DIRECTIONAL ? sun_vis : 1.0;
	LIGHT = vec4(COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY * vis * 1.25, LIGHT_COLOR.a);
}
