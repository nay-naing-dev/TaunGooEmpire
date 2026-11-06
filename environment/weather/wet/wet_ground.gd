extends Node2D
## After rain the world stays wet. Lives inside weather.tscn, so every map that has the
## weather gets it with no setup:
##   - the earth darkens and turns glossy while it rains, then dries again slowly
##   - puddles appear on their own on paths and bare earth (never on grass or in the river),
##     grow while it rains and shrink as they dry
##   - puddles mirror the sky, the characters and the lamps, and catch every lamp / torch /
##     sun highlight (specular on the wet ground)
##   - rain rings on the puddles, splashes and rings when someone walks through one
## Tip: start a map already wet with `start_wet` (e.g. a morning after a storm).

@export var soak_time := 20.0        ## seconds of rain until the ground is soaked
@export var fill_time := 45.0        ## seconds of rain until the puddles are full
@export var dry_time := 150.0        ## seconds after the rain until everything is dry
@export_range(0.0, 1.0) var start_wet := 0.0
@export var reflections := true
@export var footstep_splashes := true

const GROUND_SHADER := preload("res://environment/weather/wet/wet_ground.gdshader")
const REFLECT_SHADER := preload("res://environment/weather/wet/puddle_reflect.gdshader")
const REFLECTION := preload("res://environment/weather/wet/puddle_reflection.gd")
const SPEC_SHADER := preload("res://environment/weather/wet/spec_mask.gdshader")
const GROUPS := ["player", "actor", "npc", "enemy", "bandit", "boss", "training_bot"]

var wet := 0.0
var puddles := 0.0
var _weather: Node
var _world: Node
var _ground: Sprite2D
var _gmat: ShaderMaterial
var _rmat: ShaderMaterial
var _rmat_glow: ShaderMaterial
var _img: Image
var _spec_mat: ShaderMaterial
var _ctex: CanvasTexture
var _orig_shine := 1.0
var _orig_spec_col := Color.WHITE
var _orig_spec_tex: Texture2D
var _gpos := Vector2.ZERO
var _gsize := Vector2.ONE
var _done_src := {}
var _scan := 0.0
var _last_pos := {}
var _step := {}
var _ring_tex: GradientTexture2D
var _drop_tex: GradientTexture2D


func _ready() -> void:
	_weather = get_parent()
	_world = _weather.get_parent() if _weather else null
	_setup.call_deferred()


func _setup() -> void:
	if _world == null:
		set_process(false)
		return
	_ground = _world.get_node_or_null("Ground") as Sprite2D
	if _ground == null or _ground.texture == null:
		set_process(false)
		return
	var diffuse: Texture2D = _ground.texture
	if _ground.texture is CanvasTexture:
		diffuse = (_ground.texture as CanvasTexture).diffuse_texture
	_gpos = _ground.global_position
	_gsize = Vector2(diffuse.get_size()) * _ground.global_scale
	if _ground.texture is CanvasTexture:
		_ctex = _ground.texture as CanvasTexture
		_orig_shine = _ctex.specular_shininess
		_orig_spec_col = _ctex.specular_color
		_orig_spec_tex = _ctex.specular_texture
		var vp := SubViewport.new()
		var vs := Vector2(diffuse.get_size()) / 4.0
		vs *= minf(1.0, 1024.0 / maxf(vs.x, vs.y))
		vp.size = Vector2i(vs.ceil())
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var rect := ColorRect.new()
		rect.size = Vector2(vp.size)
		_spec_mat = ShaderMaterial.new()
		_spec_mat.shader = SPEC_SHADER
		_spec_mat.set_shader_parameter("ground_tex", diffuse)
		_spec_mat.set_shader_parameter("ground_size", _gsize)
		_spec_mat.set_shader_parameter("ground_pos", _gpos)
		rect.material = _spec_mat
		vp.add_child(rect)
		add_child(vp)
		_ctex.specular_texture = vp.get_texture()
	if _ground.material == null:
		_gmat = ShaderMaterial.new()
		_gmat.shader = GROUND_SHADER
		_ground.material = _gmat
	_rmat = ShaderMaterial.new()
	_rmat.shader = REFLECT_SHADER
	_rmat.set_shader_parameter("ground_tex", diffuse)
	_rmat.set_shader_parameter("ground_size", _gsize)
	_rmat.set_shader_parameter("ground_pos", _gpos)
	_rmat_glow = _rmat.duplicate()
	_rmat_glow.set_shader_parameter("glow", 1.0)
	_rmat_glow.set_shader_parameter("strength", 0.85)
	if footstep_splashes:
		_img = diffuse.get_image()
		if _img and _img.is_compressed():
			_img.decompress()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 0.84, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	_ring_tex = GradientTexture2D.new()
	_ring_tex.gradient = g
	_ring_tex.fill = GradientTexture2D.FILL_RADIAL
	_ring_tex.fill_from = Vector2(0.5, 0.5)
	_ring_tex.fill_to = Vector2(0.5, 0.0)
	_ring_tex.width = 64
	_ring_tex.height = 64
	var g2 := Gradient.new()
	g2.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_drop_tex = GradientTexture2D.new()
	_drop_tex.gradient = g2
	_drop_tex.fill = GradientTexture2D.FILL_RADIAL
	_drop_tex.fill_from = Vector2(0.5, 0.5)
	_drop_tex.fill_to = Vector2(0.5, 0.0)
	_drop_tex.width = 16
	_drop_tex.height = 16
	var s0 := _storm()
	wet = maxf(start_wet, s0)
	puddles = maxf(start_wet, s0) * 0.8
	_apply()


func _exit_tree() -> void:
	if _ctex:                               # the CanvasTexture is shared with the scene file
		_ctex.specular_texture = _orig_spec_tex
		_ctex.specular_color = _orig_spec_col
		_ctex.specular_shininess = _orig_shine


func _storm() -> float:
	var s = _weather.get("storm") if _weather else null
	return float(s) if s != null else 0.0


func _process(delta: float) -> void:
	var storm := _storm()
	if storm > 0.4:
		wet = move_toward(wet, 1.0, delta / soak_time)
		puddles = move_toward(puddles, 1.0, delta * storm / fill_time)
	else:
		wet = move_toward(wet, 0.0, delta / dry_time)
		puddles = move_toward(puddles, 0.0, delta / (dry_time * 0.85))
	_apply()
	if reflections:
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.6
			_add_reflections()
	if footstep_splashes and puddles > 0.05:
		_footsteps(delta)


func _apply() -> void:
	var storm := _storm()
	var t := int(Game.get("time_of_day")) if get_node_or_null("/root/Game") else 1
	var sky: Color = [Color(0.98, 0.8, 0.62), Color(0.74, 0.8, 0.92), Color(0.42, 0.5, 0.7)][clampi(t, 0, 2)]
	sky = sky.lerp(Color(0.62, 0.64, 0.7), storm * 0.6)
	if _gmat:
		_gmat.set_shader_parameter("wet", wet)
		_gmat.set_shader_parameter("puddles", puddles)
		_gmat.set_shader_parameter("rain", storm)
		_gmat.set_shader_parameter("sky", sky)
	if _spec_mat:
		_spec_mat.set_shader_parameter("wet", wet)
		_spec_mat.set_shader_parameter("puddles", puddles)
		_ctex.specular_color = Color(1, 1, 1) * clampf(wet * 1.6, 0.0, 1.0)
		_ctex.specular_shininess = lerpf(1.0, 0.5, clampf(maxf(wet, puddles), 0.0, 1.0))
	for m in [_rmat, _rmat_glow]:
		if m:
			m.set_shader_parameter("puddles", puddles)
			m.set_shader_parameter("rain", storm)


func _add_reflections() -> void:
	var srcs: Array = []
	for grp in GROUPS:
		for n in get_tree().get_nodes_in_group(grp):
			var s := _sprite_of(n)
			if s:
				srcs.append([s, false])
	for lamp in get_tree().get_nodes_in_group("night_lamp"):
		for nm in ["Off", "On"]:
			var s2 := lamp.get_node_or_null(nm) as Node2D
			if s2:
				srcs.append([s2, false])
		var gl := lamp.get_node_or_null("Glow") as Node2D
		if gl:
			srcs.append([gl, true])
	for e in srcs:
		var s: Node2D = e[0]
		if _done_src.has(s.get_instance_id()):
			continue
		_done_src[s.get_instance_id()] = true
		var r := Sprite2D.new()
		r.set_script(REFLECTION)
		r.set("src", s)
		r.name = "PuddleReflection"
		r.material = _rmat_glow if e[1] else _rmat
		s.get_parent().add_child(r)


func _sprite_of(n: Node) -> Node2D:
	if n is AnimatedSprite2D or n is Sprite2D:
		return n as Node2D
	for nm in ["AnimatedSprite2D", "Sprite2D", "Sprite"]:
		var s := n.get_node_or_null(nm)
		if s is AnimatedSprite2D or s is Sprite2D:
			return s as Node2D
	return null


# ------------------------------------------------------------------ walking through puddles
func _hash(p: Vector2) -> float:
	var p3 := Vector3(p.x, p.y, p.x) * 0.1031
	p3 = Vector3(p3.x - floorf(p3.x), p3.y - floorf(p3.y), p3.z - floorf(p3.z))
	var d := p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3.ONE * 33.33)
	p3 += Vector3.ONE * d
	var v := (p3.x + p3.y) * p3.z
	return v - floorf(v)


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	var a := lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x)
	var b := lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x)
	return lerpf(a, b, u.y)


func _fbm(p: Vector2) -> float:
	var v := 0.0
	var a := 0.5
	for i in 4:
		v += a * _noise(p)
		p = p * 2.03 + Vector2(17.1, 17.1)
		a *= 0.5
	return v


func puddle_at(w: Vector2) -> float:
	if puddles < 0.02:
		return 0.0
	if _img:
		var gp := Vector2i(((w - _gpos) / _gsize * Vector2(_img.get_size())).floor())
		if gp.x < 0 or gp.y < 0 or gp.x >= _img.get_width() or gp.y >= _img.get_height():
			return 0.0
		var c := _img.get_pixelv(gp)
		if c.g - c.b > 0.05 and c.g > c.r - 0.03:
			return 0.0                      # grass
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("is_water") and game.is_water(w):
		return 0.0
	var q := w * Vector2(1.0, 1.7)
	var n := _fbm(q * 0.011) * 0.7 + _fbm(q * 0.04 + Vector2(7, 7)) * 0.3
	var th := lerpf(0.86, 0.56, puddles)
	return smoothstep(th, th + 0.025, n)


func _footsteps(delta: float) -> void:
	for grp in ["player", "actor", "npc", "bandit", "enemy"]:
		for n in get_tree().get_nodes_in_group(grp):
			if not (n is Node2D):
				continue
			var nd := n as Node2D
			var id := nd.get_instance_id()
			var p := nd.global_position
			var last: Vector2 = _last_pos.get(id, p)
			_last_pos[id] = p
			var moved := p.distance_to(last)
			if moved < 0.3:
				continue
			var acc: float = _step.get(id, 0.0) + moved
			if acc < 14.0:
				_step[id] = acc
				continue
			_step[id] = 0.0
			if puddle_at(p) > 0.5:
				_splash(p, moved / maxf(delta, 0.001))


func _splash(p: Vector2, speed: float) -> void:
	var ring := Sprite2D.new()
	ring.texture = _ring_tex
	ring.z_as_relative = false
	ring.z_index = -8
	ring.global_position = p
	ring.scale = Vector2(0.15, 0.07)
	ring.modulate = Color(0.9, 0.95, 1.0, 0.75)
	_world.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(0.7, 0.3), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(ring, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)
	var d := CPUParticles2D.new()
	d.texture = _drop_tex
	d.z_as_relative = false
	d.z_index = 5
	d.global_position = p + Vector2(0, -1)
	d.one_shot = true
	d.explosiveness = 0.95
	d.amount = 8 if speed > 80.0 else 5
	d.lifetime = 0.4
	d.direction = Vector2(0, -1)
	d.spread = 70.0
	d.gravity = Vector2(0, 420)
	d.initial_velocity_min = 25.0
	d.initial_velocity_max = 60.0
	d.scale_amount_min = 0.12
	d.scale_amount_max = 0.25
	d.color = Color(0.8, 0.86, 0.95, 0.8)
	_world.add_child(d)
	d.emitting = true
	d.finished.connect(d.queue_free)
