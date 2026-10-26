shader_type canvas_item;
// Living light for characters.
//  - Rounded, per-body-part normal maps: as frames change (run, attack) and as the
//    character passes torches or turns around, light and shade roll across the body.
//  - Tree and building shadows from the world slide over the body when you walk under them.
//  - A soft rim light on the side facing the light.
//  - Feet sink a little into shallow water.

global uniform sampler2D world_shade : filter_linear;   // 1 = sunlit ground, 0 = shadow
global uniform vec4 world_shade_rect;                    // xy = origin, zw = size (world px)
global uniform sampler2D world_water : filter_nearest;  // R = depth, A = water
global uniform vec4 world_water_rect;
global uniform vec2 shadow_dir;                          // ground shift of a point 1 px high

uniform sampler2D normal_sheet : filter_nearest;        // used when frames come from a sheet
uniform bool use_sheet = false;
uniform float shade_strength : hint_range(0.0, 1.0) = 0.85;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.6;
uniform float contrast : hint_range(0.5, 3.0) = 1.6;
uniform vec4 water_tint : source_color = vec4(0.35, 0.52, 0.56, 1.0);

varying vec2 world_pos;
varying vec2 feet;
varying float sun_vis;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	feet = MODEL_MATRIX[3].xy;
}

void fragment() {
	vec4 c = COLOR;                                    // texture * modulate
	vec3 n = use_sheet ? texture(normal_sheet, UV).rgb : texture(NORMAL_TEXTURE, UV).rgb;
	if (dFdx(UV.x) < 0.0) { n.x = 1.0 - n.x; }        // mirrored sprite -> mirror the normals
	NORMAL_MAP = n;

	float h = max(feet.y - world_pos.y, 0.0);         // height above the ground
	vec2 g = vec2(world_pos.x, feet.y) + shadow_dir * h;
	float lit = texture(world_shade, (g - world_shade_rect.xy) / world_shade_rect.zw).r;
	sun_vis = mix(1.0, lit, shade_strength);

	vec4 w = texture(world_water, (feet - world_water_rect.xy) / world_water_rect.zw);
	if (w.a > 0.5) {
		float line = 3.0 + clamp(w.r * 4.0, 0.0, 1.0) * 9.0;   // deeper water, higher water line
		float wave = sin(world_pos.x * 0.6 + TIME * 4.0) * 0.8;
		if (h < line + wave) {
			c.rgb = mix(c.rgb, water_tint.rgb, 0.65);
			c.a *= 0.35;
		} else if (h < line + wave + 1.0) {
			c.rgb = mix(c.rgb, vec3(0.9, 0.97, 1.0), 0.6);      // bright water line
		}
	}
	COLOR = c;
}

void light() {
	float nl = dot(NORMAL, LIGHT_DIRECTION);
	float vis = LIGHT_IS_DIRECTIONAL ? sun_vis : 1.0;
	float diff = pow(clamp(nl * 0.5 + 0.5, 0.0, 1.0), contrast);
	float rim = pow(clamp(1.0 - NORMAL.z, 0.0, 1.0), 2.0) * clamp(nl, 0.0, 1.0) * rim_strength;
	vec3 l = LIGHT_COLOR.rgb * LIGHT_ENERGY * vis;
	LIGHT = vec4(COLOR.rgb * l * diff * 1.6 + l * rim * 0.5, LIGHT_COLOR.a);
}
