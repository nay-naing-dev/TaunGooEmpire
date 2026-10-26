shader_type canvas_item;
// Turns the whole screen into coloured ASCII text, like a terminal-art game.
// Each cell takes the colour of the picture underneath it and picks a character:
//   strong edges  -> - / | \  (follows the shape: grass blades, ripples, outlines)
//   flat areas    -> denser characters for brighter areas ( . ' ; r ? v ... @ )

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D glyphs : filter_linear;      // 20 glyphs in a row: 16 density + 4 edge
uniform vec2 cell = vec2(8.0, 13.0);           // character size in screen pixels
uniform float edge_threshold = 0.11;
uniform float contrast = 2.1;                  // higher = more empty dark space
uniform float brightness = 1.25;
uniform float saturation = 1.25;
uniform float vivid = 1.6;                     // pushes colours apart (green grass, blue water)
uniform vec4 background : source_color = vec4(0.01, 0.015, 0.03, 1.0);
uniform float glow = 0.05;                     // faint colour behind the characters

const float DENSITY = 16.0;
const float GLYPHS = 20.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 cid = floor(px / cell);
	vec2 cuv = fract(px / cell);
	vec2 center = (cid + 0.5) * cell * SCREEN_PIXEL_SIZE;
	vec2 step_uv = cell * SCREEN_PIXEL_SIZE;

	// average colour of the cell (4 taps) and neighbours for the edge test
	vec3 c = (texture(screen, center + step_uv * vec2(-0.25, -0.25)).rgb
			+ texture(screen, center + step_uv * vec2(0.25, -0.25)).rgb
			+ texture(screen, center + step_uv * vec2(-0.25, 0.25)).rgb
			+ texture(screen, center + step_uv * vec2(0.25, 0.25)).rgb) * 0.25;
	float l0 = luma(c);
	c = max(mix(vec3(l0), c, vivid), 0.0);
	float l = luma(c);
	float lx = luma(texture(screen, center + vec2(step_uv.x * 0.5, 0.0)).rgb) - luma(texture(screen, center - vec2(step_uv.x * 0.5, 0.0)).rgb);
	float ly = luma(texture(screen, center + vec2(0.0, step_uv.y * 0.5)).rgb) - luma(texture(screen, center - vec2(0.0, step_uv.y * 0.5)).rgb);
	float g = length(vec2(lx, ly));

	float idx;
	if (g > edge_threshold) {
		// the stroke runs along the edge (perpendicular to the gradient)
		float a = atan(ly, lx);                       // gradient angle
		float d = mod(a + 3.14159265 / 8.0, 3.14159265);
		int k = int(floor(d / (3.14159265 / 4.0)));   // 0..3
		// gradient horizontal -> vertical stroke, etc.
		int map[4] = int[4](2, 3, 0, 1);
		idx = DENSITY + float(map[k]);
	} else {
		idx = clamp(floor(pow(clamp(l * 1.15, 0.0, 1.0), contrast) * (DENSITY - 1.0) + 0.5), 0.0, DENSITY - 1.0);
	}
	vec2 guv = vec2((idx + cuv.x) / GLYPHS, cuv.y);
	float ink = texture(glyphs, guv).r;

	// glyph colour = the hue underneath, lifted so dark scenes still read (like a terminal)
	vec3 hue = c / max(max(c.r, max(c.g, c.b)), 0.05);
	vec3 col = mix(vec3(1.0), hue, clamp(saturation * 0.8, 0.0, 1.0)) * (0.25 + 0.95 * pow(l, 0.7)) * brightness;
	vec3 outc = background.rgb + c * glow + col * ink;
	COLOR = vec4(outc, 1.0);
}
