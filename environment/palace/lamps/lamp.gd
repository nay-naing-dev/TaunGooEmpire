extends StaticBody2D
## Night lamp: unlit in the morning and by day, lights itself at night (Game.time_of_day == 2).
## Flickering warm light, glowing glass / living flame, rising embers.
## Just drop the scene into the map under Objects (so it y-sorts).

@export var open_fire := false
@export var always_on := false         ## e.g. inside a dark interior
@export_range(0.0, 3.0) var brightness := 1.0
@export var fade_time := 1.6

var _lit := 0.0
var _lights: Array[PointLight2D] = []
var _halos: Array[Sprite2D] = []
var _embers: Array[CPUParticles2D] = []
var _halo_scale := 1.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _atmos: CanvasModulate
@onready var on_spr: Sprite2D = $On
@onready var glow: Sprite2D = $Glow


func _ready() -> void:
	add_to_group("night_lamp")
	_noise.seed = randi()
	_noise.frequency = 0.35 if open_fire else 0.15
	_t = randf() * 100.0
	for c in get_children():
		if c is PointLight2D: _lights.append(c)
		elif c is CPUParticles2D: _embers.append(c)
		elif c is Sprite2D and c.name.begins_with("Halo"):
			_halos.append(c)
			_halo_scale = c.scale.x
	if glow.material:
		glow.material = glow.material.duplicate()
		glow.material.set_shader_parameter("seed", randf())
	_lit = 1.0 if _is_night() else 0.0
	_apply()


func _is_night() -> bool:
	if always_on:
		return true
	var g := get_node_or_null("/root/Game")
	if g == null:
		return false
	return int(g.get("time_of_day")) == 2 or bool(g.get("night_mode"))


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if _is_night() else 0.0
	if _lit != target:
		_lit = move_toward(_lit, target, delta / maxf(fade_time, 0.01))
	elif _lit <= 0.0 and not on_spr.visible:
		return
	_apply()


func _apply() -> void:
	var lit := _lit
	on_spr.visible = lit > 0.0
	on_spr.modulate.a = lit
	glow.visible = lit > 0.0
	for e in _embers:
		e.emitting = lit > 0.6
	for h in _halos:
		h.visible = lit > 0.0
	for l in _lights:
		l.enabled = lit > 0.0
	if lit <= 0.0:
		return
	# flicker: layered noise; open fire jumps more than a flame behind glass
	var n := _noise.get_noise_1d(_t * 30.0)
	var n2 := _noise.get_noise_1d(_t * 90.0 + 50.0)
	var f := 1.0 + n * (0.24 if open_fire else 0.1) + n2 * (0.1 if open_fire else 0.04)
	# emissive parts cancel the night tint (CanvasModulate) so flames keep their colour
	if _atmos == null and get_tree().current_scene:
		_atmos = get_tree().current_scene.get_node_or_null("Atmosphere") as CanvasModulate
	var comp := Color(1, 1, 1)
	if _atmos:
		var a := _atmos.color
		comp = Color(1.0 / maxf(a.r, 0.2), 1.0 / maxf(a.g, 0.2), 1.0 / maxf(a.b, 0.2))
	var e := lit * f * brightness
	glow.modulate = Color(comp.r * (0.85 + 0.25 * f), comp.g * (0.8 + 0.25 * f), comp.b * 0.95, lit)
	for l in _lights:
		l.energy = (1.35 if open_fire else 1.1) * e
		l.offset = Vector2(n2 * 1.5, n * 1.0) if open_fire else Vector2.ZERO
	for h in _halos:
		h.modulate = Color(comp.r, comp.g, comp.b, clampf(0.55 * e, 0.0, 1.0))
		h.scale = Vector2.ONE * _halo_scale * (1.0 + n * (0.14 if open_fire else 0.05))
