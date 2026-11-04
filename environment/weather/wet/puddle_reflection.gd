extends Sprite2D
## Upside-down copy of a character or lamp that only shows inside rain puddles
## (puddle_reflect.gdshader). WetGround creates these and they follow the sprite every frame.

var src: Node2D


func _ready() -> void:
	z_as_relative = false
	z_index = -9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if not is_instance_valid(src):
		queue_free()
		return
	if not visible:
		return
	if src is AnimatedSprite2D:
		var a := src as AnimatedSprite2D
		if a.sprite_frames == null:
			return
		texture = a.sprite_frames.get_frame_texture(a.animation, a.frame)
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
	position = src.position
	rotation = -src.rotation
	scale = Vector2(src.scale.x, -src.scale.y)
	var m := src.modulate
	self_modulate = Color(1, 1, 1, m.a * (1.0 if src.is_visible_in_tree() else 0.0))
