extends StaticBody2D
## Torch / street lamp that lights itself in the evening and goes out in the morning.
## - By day: just the post (Sprite2D), fire out.
## - From dusk (Game.hour) the fire fades in: Fire is the burning part of the art drawn
##   unshaded (it does not darken with the night), Halo a soft additive glow around it,
##   Light lights the ground and everything nearby. All of it flickers.
## - While the player is inside a house the lights are off (they would shine into the room).

## The lamp is lit from this hour ...
@export var on_hour := 18.0
## ... until this hour the next morning.
@export var off_hour := 6.0
## Hours it takes to light / go out.
@export var fade_hours := 0.75
@export var flicker := 0.12

@onready var _light: PointLight2D = $Light
@onready var _fire: Sprite2D = $Fire
@onready var _halo: Sprite2D = $Halo
@onready var _embers: CPUParticles2D = get_node_or_null("Embers")
var _base_energy := 1.0
var _base_halo := 1.0
var _lit := 0.0
var _t := randf() * 10.0


func _ready() -> void:
	add_to_group("night_lamp")
	_base_energy = _light.energy
	_base_halo = _halo.modulate.a
	snap()


## Lit / out right away for the current hour (after the clock jumps, e.g. sleeping).
func snap() -> void:
	_lit = _target()
	_apply()


## How lit the lamp should be at the current hour (0 out .. 1 burning).
func _target() -> float:
	var h: float = Game.hour
	var half := fade_hours * 0.5
	if h >= 12.0:
		return smoothstep(on_hour - half, on_hour + half, h)
	return 1.0 - smoothstep(off_hour - half, off_hour + half, h)


func _process(delta: float) -> void:
	_t += delta
	_lit = move_toward(_lit, _target(), delta * 2.0)
	_apply()


func _apply() -> void:
	var f := 1.0 + flicker * (sin(_t * 7.0) * 0.6 + sin(_t * 17.3) * 0.4)
	_fire.visible = _lit > 0.01
	_fire.modulate.a = _lit
	_halo.visible = _fire.visible
	_halo.modulate.a = _base_halo * _lit * f
	var indoors: bool = Game.get("indoors")
	_light.visible = _fire.visible and not indoors
	_light.energy = _base_energy * _lit * f
	if _embers:
		_embers.emitting = _lit > 0.5
