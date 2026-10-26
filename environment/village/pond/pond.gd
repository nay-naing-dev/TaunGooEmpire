extends Node2D
## Nature pool. The water joins the world's water, so characters wade at the
## edge, reflect in it, and rain / footsteps / fish make ripple rings on it.

## How deep the pool counts for wading (0..1).
@export var wading_depth := 0.6


func _ready() -> void:
	_register.call_deferred()


func _register() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or game.get("water_image") == null:
		return
	var img: Image = game.water_image.duplicate()
	var pm: Image = $Water.texture.get_image()
	if pm.is_compressed():
		pm.decompress()
	var o := Vector2i((global_position - game.water_rect.position).round())
	for y in pm.get_height():
		for x in pm.get_width():
			var c := pm.get_pixel(x, y)
			var q := o + Vector2i(x, y)
			if c.a > 0.5 and q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, Color(c.r * wading_depth, 0, 0, 1))
	game.set_world_water(ImageTexture.create_from_image(img), game.water_rect)
