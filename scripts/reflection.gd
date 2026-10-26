extends Sprite2D
## Upside-down copy of a sprite, drawn on the water surface (water_reflection.gdshader).
## Game.add_reflection() creates these; it follows the sprite's animation every frame.

var src: Node2D
## Water line in the source sprite's local pixels (0 = its origin, i.e. the feet).
var mirror_y := 0.0
## How far below the sprite to look for water before showing the reflection.
var check_reach := 70.0
var _check := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = -9                 # just above the water, below everything standing
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func _process(delta: float) -> void:
	if not is_instance_valid(src):
		queue_free()
		return
	if get_parent() != src.get_parent():          # e.g. moved to the ASCII clear layer
		reparent.call_deferred(src.get_parent(), false)
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		visible = src.is_visible_in_tree() and Game.water_near(
				src.global_position + Vector2(0, mirror_y * src.global_scale.y), check_reach)
	if not visible:
		return
	if src is AnimatedSprite2D:
		var a := src as AnimatedSprite2D
		texture = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		hframes = 1
		vframes = 1
		region_enabled = false
	else:
		var s := src as Sprite2D
		texture = s.texture
		hframes = s.hframes
		vframes = s.vframes
		frame = s.frame
		region_enabled = s.region_enabled
		region_rect = s.region_rect
	flip_h = src.get("flip_h")
	centered = src.get("centered")
	offset = src.get("offset")
	position = src.position + Vector2(0, 2.0 * mirror_y * src.scale.y)
	rotation = -src.rotation
	scale = Vector2(src.scale.x, -src.scale.y)
	modulate.a = src.modulate.a
