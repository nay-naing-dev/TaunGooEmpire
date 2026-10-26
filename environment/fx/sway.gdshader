shader_type canvas_item;
// Wind for trees, palms and their shadows: the top moves, the base stays.
// Gusts (wind.gdshaderinc) roll across the map and make the leaves lean and shimmer.
#include "res://environment/fx/wind.gdshaderinc"

uniform float strength = 2.5;        // pixels at the very top
uniform float speed = 1.3;
uniform float phase = 0.0;
uniform float gust_strength = 1.8;   // extra lean when a gust passes
uniform float rustle = 0.08;         // leaves shimmer in a gust (0 = off)

varying float gust;

void vertex() {
	gust = wind_gust(MODEL_MATRIX[3].xy);
	float top = 1.0 - UV.y;
	VERTEX.x += (sin(TIME * speed + phase) * strength * (0.7 + gust) + gust * strength * gust_strength) * top * top
		+ sin(TIME * speed * 2.3 + phase * 1.7) * strength * 0.3 * top * (1.0 + gust);
}

void fragment() {
	float top = 1.0 - UV.y;
	float flick = sin(TIME * 7.0 + UV.x * 61.0 + UV.y * 47.0 + phase) * sin(TIME * 4.3 + UV.y * 83.0 - UV.x * 29.0);
	COLOR.rgb *= 1.0 + rustle * (0.35 + gust) * flick * top;
}
