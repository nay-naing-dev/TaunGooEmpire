shader_type canvas_item;
// Put on the map's Ground sprite by WetGround: darker, glossier earth after rain, puddles on
// the paths that mirror the sky and catch every lamp and torch light, rain rings on them.
#include "res://environment/weather/wet/wet_common.gdshaderinc"
uniform float wet = 0.0;          // 0 dry .. 1 soaked
uniform float puddles = 0.0;      // puddle level
uniform float rain = 0.0;         // drops falling now
uniform vec4 sky : source_color = vec4(0.72, 0.78, 0.9, 1.0);
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	vec3 c = albedo.rgb;
	float dirt = wet_dirt(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
	float pm = wet_puddle(world, puddles, dirt);
	// soaked earth: darker, deeper colour; grass darkens less
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 soaked = clamp(mix(vec3(l), c, 1.3) * 0.68, 0.0, 1.0);
	c = mix(c, soaked, wet * mix(0.55, 0.9, dirt));
	// puddle: dark water, sky reflection brighter towards the far edge, soft wet rim
	vec3 rp = wet_ripples(world, TIME, rain) * pm;
	float sky_n = wet_fbm(world * vec2(0.006, 0.012) + vec2(TIME * 0.02, 0.0) + rp.yz * 0.4);
	vec3 refl = sky.rgb * (0.45 + 0.55 * sky_n);
	vec3 water = mix(c * 0.3, refl, 0.55);
	water += vec3(0.5) * rp.x * 0.6;
	float rim = clamp(wet_puddle(world + vec2(0.0, -3.0), puddles, dirt) - pm, 0.0, 1.0);
	c = mix(c, water, pm);
	c *= 1.0 - rim * 0.35;
	COLOR = vec4(c, albedo.a);
	// flat mirror in the puddles (with ripple slopes), normal map elsewhere
	vec3 nm = texture(NORMAL_TEXTURE, UV).rgb;
	vec3 flat_n = vec3(0.5 + rp.y * 0.35, 0.5 + rp.z * 0.35, 1.0);
	NORMAL_MAP = mix(nm, flat_n, pm);
	// the glints come from the specular map WetGround renders (spec_mask.gdshader)
}
