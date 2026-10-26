extends Node2D
## Rain and thunderstorm for the Taungoo world.
##   F4 : rain on / off   (works together with F3 night and F2 ASCII)
## Rain streaks, splashes on the ground, rain rings on the river, darker stormy
## light, stronger wind in the grass and trees, lightning that flashes the sky
## and sometimes strikes the ground on screen, thunder and rain sounds.
## Put this scene inside the world (drag weather.tscn onto TaungooWorld).

@export var raining := false
@export_range(0.0, 1.0, 0.05) var intensity := 1.0
@export var lightning := true
@export var min_lightning_gap := 4.0
@export var max_lightning_gap := 11.0
## Chance that a lightning flash is a visible bolt hitting the ground on screen.
@export_range(0.0, 1.0, 0.05) var strike_chance := 0.5
@export var storm_tint := Color(0.56, 0.6, 0.72)
## How bright a lightning flash gets (0.3 = bright but not blinding).
@export_range(0.0, 1.0, 0.05) var flash_strength := 0.3
@export var rain_volume_db := -8.0
@export var thunder_volume_db := -4.0
@export var toggle_key: Key = KEY_F4

const ADD := preload("res://environment/weather/weather_fx.gd")
var storm := 0.0          # 0 dry .. 1 full storm (fades in and out)
var _layer: CanvasLayer
var _dim: ColorRect
var _rain: ColorRect
var _flash: ColorRect
var _fx: Node2D           # splashes on the ground
var _sky: Node2D          # lightning bolts
var _light: DirectionalLight2D
var _rain_snd: AudioStreamPlayer
var _thunder_snd: AudioStreamPlayer
var _next := 3.0
var _shake := 0.0
var _sways: Array = []
var _was := false
var _glow: GradientTexture2D


func _ready() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(0.5, 0.0)
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	_dim = _full_rect(Color.WHITE)
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_dim.material = mul
	_rain = _full_rect(Color.WHITE)
	var rm := ShaderMaterial.new()
	rm.shader = preload("res://environment/weather/rain.gdshader")
	_rain.material = rm
	_flash = _full_rect(Color(0.78, 0.84, 1.0, 0.0))
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = addm
	_fx = ADD.new()
	_fx.z_as_relative = false
	_fx.z_index = -7
	add_child(_fx)
	_sky = ADD.new()
	_sky.bolts_mode = true
	_sky.z_as_relative = false
	_sky.z_index = 20
	add_child(_sky)
	_light = DirectionalLight2D.new()
	_light.color = Color(0.72, 0.8, 1.0)
	_light.energy = 0.0
	_light.height = 0.4
	add_child(_light)
	_rain_snd = AudioStreamPlayer.new()
	var rs: AudioStreamWAV = preload("res://environment/weather/rain_loop.wav").duplicate()
	rs.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rs.loop_begin = 0
	rs.loop_end = int(rs.get_length() * rs.mix_rate)
	_rain_snd.stream = rs
	_rain_snd.volume_db = -60.0
	add_child(_rain_snd)
	_thunder_snd = AudioStreamPlayer.new()
	add_child(_thunder_snd)
	storm = 1.0 if raining else 0.0
	if raining:
		_rain_snd.play()


func _full_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	return r


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		set_rain(not raining)


func set_rain(on: bool) -> void:
	raining = on
	if on and not _rain_snd.playing:
		_rain_snd.play()
	_next = randf_range(2.0, 5.0)


func _process(delta: float) -> void:
	storm = move_toward(storm, 1.0 if raining else 0.0, delta / 2.5)
	var k := storm * intensity
	# under a roof: no rain streaks on screen, rain sound muffled
	var inside: bool = Game.get("indoors") == true
	var w := get_parent()
	# darker, bluer light; sun, sun shafts and fireflies fade out
	_dim.color = Color.WHITE.lerp(storm_tint, k)
	if k > 0.001:
		if w.has_node("Sun"):
			var sun: DirectionalLight2D = w.get_node("Sun")
			sun.energy = minf(sun.energy, lerpf(0.5, 0.1, k))
		if w.has_node("SunShafts"):
			w.get_node("SunShafts").modulate.a = minf(w.get_node("SunShafts").modulate.a, 1.0 - k)
		if w.has_node("Fireflies"):
			w.get_node("Fireflies").modulate.a = minf(w.get_node("Fireflies").modulate.a, 1.0 - k)
		_was = true
	elif _was:
		_was = false
		_rain_snd.stop()
		if w.has_method("apply_night"):
			w.apply_night(Game.night_mode if get_node_or_null("/root/Game") else false, true)
	# rain on screen, moving with the camera
	var cam := get_viewport().get_camera_2d()
	var rm: ShaderMaterial = _rain.material
	rm.set_shader_parameter("amount", k)
	rm.set_shader_parameter("rect_size", _rain.size)
	rm.set_shader_parameter("cam_pos", -get_viewport().get_canvas_transform().origin)
	_rain.visible = k > 0.01 and not inside
	_rain_snd.volume_db = lerpf(-50.0, rain_volume_db, sqrt(k)) - (9.0 if inside else 0.0)
	# splashes on the ground, rings on the water
	if cam and k > 0.01:
		var view := _view(cam)
		var rip := w.get_node_or_null("Ripples")
		var n := int(260.0 * k * delta + randf())
		for i in n:
			var p := view.position + Vector2(randf() * view.size.x, randf() * view.size.y)
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("is_water") and game.is_water(p):
				if rip and randf() < 0.5:
					rip.add_ring(p, randf_range(3.0, 8.0), randf_range(0.6, 0.9))
			else:
				_fx.splash(p)
	# wind
	_storm_wind(k)
	# lightning
	if lightning and k > 0.6:
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(min_lightning_gap, max_lightning_gap)
			strike()
	# camera shake after a close strike
	if cam:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, delta * 14.0)


func _view(cam: Camera2D) -> Rect2:
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size / 2.0, size)


## Lightning now. ground = true forces a bolt on screen, false only a sky flash.
func strike(ground := -1) -> void:
	var cam := get_viewport().get_camera_2d()
	var hit := randf() < strike_chance if ground < 0 else ground == 1
	# flicker: flash, dim, bigger flash, fade
	var t := create_tween()
	var peak := flash_strength * (1.0 if hit else 0.6)
	t.tween_property(_flash, "color:a", peak * 0.6, 0.04)
	t.parallel().tween_property(_light, "energy", peak * 3.0, 0.04)
	t.tween_property(_flash, "color:a", peak * 0.08, 0.07)
	t.parallel().tween_property(_light, "energy", peak * 0.4, 0.07)
	t.tween_property(_flash, "color:a", peak, 0.03)
	t.parallel().tween_property(_light, "energy", peak * 4.5, 0.03)
	t.tween_property(_flash, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_light, "energy", 0.0, 0.55)
	_light.rotation = randf_range(0.0, TAU)
	var delay := randf_range(1.0, 2.8)
	var loud := thunder_volume_db - 6.0
	if hit and cam:
		var view := _view(cam)
		var p := view.position + Vector2(randf_range(0.15, 0.85) * view.size.x, randf_range(0.35, 0.9) * view.size.y)
		_sky.bolt(p, view.position.y - 60.0)
		_fx.scorch(p)
		var pl := PointLight2D.new()
		pl.texture = _glow
		pl.texture_scale = 9.0
		pl.color = Color(0.75, 0.82, 1.0)
		pl.energy = 4.0
		pl.position = p
		add_child(pl)
		var lt := pl.create_tween()
		lt.tween_property(pl, "energy", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lt.tween_callback(pl.queue_free)
		_shake = 5.0
		delay = randf_range(0.05, 0.25)
		loud = thunder_volume_db
	_thunder.call_deferred(delay, hit, loud)


func _thunder(delay: float, near: bool, db: float) -> void:
	await get_tree().create_timer(delay).timeout
	var s: AudioStream
	if near:
		s = preload("res://environment/weather/thunder_near.wav")
	else:
		s = [preload("res://environment/weather/thunder_far.wav"), preload("res://environment/weather/thunder_roll.wav")].pick_random()
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.volume_db = db
	pl.pitch_scale = randf_range(0.85, 1.1)
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)


## Grass and trees move harder in the storm.
func _storm_wind(k: float) -> void:
	var w := get_parent()
	var grass := w.get_node_or_null("GrassField")
	if grass and grass.has_method("set_storm"):
		grass.set_storm(k)
	if _sways.is_empty() and k > 0.0:
		for n in w.find_children("*", "Sprite2D", true, false):
			var m = n.material
			if m is ShaderMaterial and m.shader and m.shader.resource_path.ends_with("sway.gdshader"):
				_sways.append([m, m.get_shader_parameter("strength"), m.get_shader_parameter("gust_strength")])
	for e in _sways:
		var m: ShaderMaterial = e[0]
		if e[1] != null:
			m.set_shader_parameter("strength", float(e[1]) * (1.0 + 1.3 * k))
		if e[2] != null:
			m.set_shader_parameter("gust_strength", float(e[2]) * (1.0 + 1.2 * k))
