extends StaticBody2D
## Palace building / wall: turns see-through when the player walks behind it.

@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.4
@onready var _sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	var target := 1.0
	var rect := _sprite.get_rect()
	for p in get_tree().get_nodes_in_group("player"):
		var local := to_local((p as Node2D).global_position)
		if local.y < -4.0 and rect.grow(-8).has_point(local + Vector2(0, -26)):
			target = faded_alpha
			break
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, delta * 4.0)
