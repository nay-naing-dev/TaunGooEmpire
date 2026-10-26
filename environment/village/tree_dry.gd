extends StaticBody2D
## Dry-season tree: canopy sways in the wind (each tree its own timing) and
## turns see-through when the player walks behind it.

@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.42
@export var fade_speed: float = 4.0
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if _sprite.material:
		_sprite.material = _sprite.material.duplicate()
		_sprite.material.set_shader_parameter("phase", randf() * TAU)


func _process(delta: float) -> void:
	var target := 1.0
	var rect := _sprite.get_rect()
	for p in get_tree().get_nodes_in_group("player"):
		var local := to_local((p as Node2D).global_position)
		if local.y < -4.0 and rect.grow(-10).has_point(local + Vector2(0, -24)):
			target = faded_alpha
			break
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, delta * fade_speed)
