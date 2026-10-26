extends "res://characters/npcs/villager.gd"
## Water buffalo: plods slowly between its patrol points, grazes (head bob)
## while waiting, swishes its tail. Bell clinks are left to the sound designer.

var _graze := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	# slow heavy gait instead of the villager's quick step bob
	if velocity.length() > 1.0 and _wait <= 0.0:
		sprite.offset.y = _base - absf(sin(_t * 3.2)) * 1.0
		sprite.rotation = sin(_t * 3.2) * 0.01
	else:
		_graze += delta
		sprite.offset.y = _base + (0.5 + 0.5 * sin(_graze * 0.9)) * 1.2
		sprite.rotation = 0.0
	velocity = velocity.move_toward(Vector2.ZERO, 40.0 * delta)
