extends Node2D
## Forest tree / bush / rock. Each one sways on its own timing; trees turn
## see-through when the player walks behind them.

@export var fade := true
@export_range(0.0, 1.0, 0.05) var faded_alpha := 0.4
@onready var _sprite: Sprite2D = $Sprite2D
var _rect: Rect2
var _t := 0.0


func _ready() -> void:
	if _sprite.material:
		_sprite.material = _sprite.material.duplicate()
		_sprite.material.set_shader_parameter("phase", randf() * TAU)
	_rect = _sprite.get_rect().grow(-10)
	set_process(fade)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 and is_equal_approx(_sprite.modulate.a, 1.0):
		return
	_t = 0.15        # look for the player a few times a second, not every frame
	var target := 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var local := to_local(p.global_position)
		if local.y < -4.0 and _rect.has_point(local + Vector2(0, -24)):
			target = faded_alpha
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, delta * 4.0 + 0.1)
