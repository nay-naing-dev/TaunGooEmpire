shader_type canvas_item;
render_mode unshaded;
// Only draw where the world has water (used by the ripple rings).
global uniform sampler2D world_water : filter_nearest;
global uniform vec4 world_water_rect;
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	if (texture(world_water, (wp - world_water_rect.xy) / world_water_rect.zw).a < 0.5) discard;
}
