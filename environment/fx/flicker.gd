extends Node2D
## Flickers a lamp's light and glow, and gently pulses god rays.

@export var amount: float = 0.08
@export var speed: float = 1.0
var _t := randf() * 10.0
var _base_energy := 1.0
var _base_alpha := 1.0
var _light: PointLight2D


func _ready() -> void:
	var me: Node = self
	if me is PointLight2D:
		_light = me
		_base_energy = _light.energy
	_base_alpha = modulate.a


func _process(delta: float) -> void:
	_t += delta * speed
	var f := 1.0 + amount * (sin(_t * 7.0) * 0.6 + sin(_t * 17.3) * 0.4)
	if _light:
		_light.energy = _base_energy * f
	else:
		modulate.a = _base_alpha * f
