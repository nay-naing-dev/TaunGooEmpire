extends "res://environment/taungoo/building.gd"
## The big golden temple.
## - Gold that shines: sky reflection, sun / torch / lightning highlights, a glint that
##   sweeps across it and sparkles (gold.gdshader, tune it on Sprite2D -> Material).
## - Reflected in the river / moat when it stands near water.

## Draw the temple's reflection in nearby water.
@export var water_reflection := true
## The reflection is mirrored this many world pixels below the temple's front corner.
## 0 = right at the base (looks best when the temple stands on the bank).
@export var water_line := 0.0
@export_range(0.0, 1.0, 0.05) var reflection_strength := 0.7

var _mat: ShaderMaterial
var _sun := 1.0
var _refl: ShaderMaterial


func _ready() -> void:
	super._ready()
	_mat = $Sprite2D.material
	if water_reflection:
		_add_reflection.call_deferred()


func _add_reflection() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method("is_water"):
		return
	var line := water_line
	var near := false
	for dy in range(0, 240, 8):
		for dx in [-200, -100, 0, 100, 200]:
			if game.is_water(global_position + Vector2(dx, dy)):
				near = true
	if not near:
		return                                       # no water near this temple
	var r := Sprite2D.new()
	r.set_script(preload("res://scripts/reflection.gd"))
	r.name = "Reflection"
	r.set("src", $Sprite2D)
	r.set("mirror_y", line / global_scale.y)
	r.set("check_reach", 260.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://environment/fx/water_reflection.gdshader")
	m.set_shader_parameter("strength", reflection_strength)
	m.set_shader_parameter("fade_px", 420.0)
	m.set_shader_parameter("wobble", 1.3)
	m.set_shader_parameter("tint", Color(1.0, 0.92, 0.72))
	r.material = m
	_refl = m
	add_child(r)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	super._process(delta)
	# how much sun is on the gold (night and storms make it duller)
	var world := get_tree().current_scene
	var sun := 1.0
	if world and world.has_node("Sun"):
		sun = clampf(world.get_node("Sun").energy / 0.5, 0.0, 1.0)
	_sun = lerpf(_sun, sun, minf(delta * 3.0, 1.0))
	_mat.set_shader_parameter("sunlight", _sun)
	if _refl:
		_refl.set_shader_parameter("strength", reflection_strength * lerpf(0.3, 1.0, _sun))
