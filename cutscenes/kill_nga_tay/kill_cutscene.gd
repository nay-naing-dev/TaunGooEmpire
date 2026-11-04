extends CanvasLayer
## Cinematic: the MC kills Nga Tay (played when the player chooses to kill him).
## Night, heavy rain, lightning, all the way through.
##   1. Enemy view (comic panels): Nga Tay's back -> MC walks in -> points the blade
##      -> close-up -> lunge -> the stab, blood.
##   2. Isometric: stab, kick to the chest, pull the sword out.
##   3. Exhausted, he leans on the sword and sinks to his knees.
##   4. Close-ups: kneeling in the blood, then his face, crying.
##
## Usage (from the story / quest script):
##   var cs = preload("res://cutscenes/kill_nga_tay/kill_cutscene.tscn").instantiate()
##   get_tree().root.add_child(cs)
##   cs.play()
##   await cs.finished          # it frees itself afterwards
## Hold Esc (ui_cancel) to skip.

signal finished

@export var pause_game := true
@export var skippable := true
@export var rain_volume_db := -6.0
@export var thunder_volume_db := -2.0

const IMG := "res://cutscenes/kill_nga_tay/img/"
const NIGHT := Color(0.62, 0.66, 0.86)       # night tint over the dusk-coloured art

var _stage: Control
var _shot: TextureRect
var _shot2: TextureRect          # cross-fade partner
var _bg: ColorRect
var _ground: ColorRect
var _hidden: Array = []          # map actors hidden while the cutscene shows the map
var _back: TextureRect           # dim, soft, screen-filling copy of the panel
var _rain: ColorRect
var _flash: ColorRect
var _fade: ColorRect
var _top: ColorRect
var _bot: ColorRect
var _hint: Label
var _rain_snd: AudioStreamPlayer
var _shake := 0.0
var _skip_t := 0.0
var _done := false
var _was_paused := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_bg = _rect(root, Color(0.02, 0.025, 0.04))
	# the real forest map shows through behind the isometric shots, darkened to a stormy night
	_ground = _rect(root, Color(0.17, 0.2, 0.34))
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_ground.material = mul
	_ground.visible = false
	_back = TextureRect.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.modulate = Color(0.22, 0.24, 0.34, 0.0)
	root.add_child(_back)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)
	_shot2 = _tex()
	_shot = _tex()
	_rain = _rect(root, Color.WHITE)
	var rm := ShaderMaterial.new()
	rm.shader = load("res://environment/weather/rain.gdshader")
	rm.set_shader_parameter("amount", 1.0)
	rm.set_shader_parameter("drop_color", Color(0.75, 0.82, 0.98, 0.5))
	rm.set_shader_parameter("slant", 0.16)
	_rain.material = rm
	_flash = _rect(root, Color(0.8, 0.86, 1.0, 0.0))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	_top = _rect(root, Color.BLACK)
	_bot = _rect(root, Color.BLACK)
	_fade = _rect(root, Color(0, 0, 0, 1))
	_hint = Label.new()
	_hint.text = "Hold Esc to skip"
	_hint.modulate = Color(1, 1, 1, 0.0)
	_hint.add_theme_font_size_override("font_size", 12)
	root.add_child(_hint)
	_rain_snd = AudioStreamPlayer.new()
	var rs = load("res://environment/weather/rain_loop.wav")
	if rs is AudioStreamWAV:
		rs = rs.duplicate()
		rs.loop_mode = AudioStreamWAV.LOOP_FORWARD
		rs.loop_begin = 0
		rs.loop_end = int(rs.get_length() * rs.mix_rate)
	_rain_snd.stream = rs
	_rain_snd.volume_db = -40.0
	add_child(_rain_snd)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _rect(parent: Control, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _tex() -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = Color(1, 1, 1, 0)
	_stage.add_child(t)
	return t


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	(_rain.material as ShaderMaterial).set_shader_parameter("rect_size", s)
	var bar := s.y * 0.09
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.size = Vector2(s.x, bar)
	_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bot.position = Vector2(0, s.y - bar)
	_bot.size = Vector2(s.x, bar)
	_hint.position = s - Vector2(130, bar * 0.5 + 10)


func _process(delta: float) -> void:
	if not visible:
		return
	if _shake > 0.0:
		_stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 30.0)
	else:
		_stage.position = Vector2.ZERO
	if skippable and not _done:
		if Input.is_action_pressed("ui_cancel"):
			_skip_t += delta
			_hint.modulate.a = 1.0
			if _skip_t > 0.8:
				_end()
		else:
			_skip_t = 0.0


# ------------------------------------------------------------------ shot helpers
func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## Show an image: fills `height` of the screen, slow push-in from zoom0 to zoom1 over `secs`,
## cross-fading from the previous shot in `fade` seconds.
func _show(img: String, secs: float, zoom0 := 1.0, zoom1 := 1.06, height := 0.82, fade := 0.35, pan := Vector2.ZERO, tint := NIGHT) -> void:
	if _done:
		return
	var old := _shot
	_shot = _shot2
	_shot2 = old
	var tex: Texture2D = load(IMG + img + ".png")
	var s := get_viewport().get_visible_rect().size
	var h := s.y * height
	var w := h * tex.get_width() / float(tex.get_height())
	if w > s.x * 0.98:
		w = s.x * 0.98
		h = w * tex.get_height() / float(tex.get_width())
	_shot.texture = tex
	var panel := img.begins_with("panel")
	_back.texture = tex if panel else null
	create_tween().tween_property(_back, "modulate:a", 1.0 if panel else 0.0, fade + 0.01)
	_shot.size = Vector2(w, h)
	_shot.pivot_offset = _shot.size * 0.5
	_shot.position = (s - _shot.size) * 0.5
	_shot.scale = Vector2.ONE * zoom0
	_shot.move_to_front()
	_shot.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	var t := create_tween().set_parallel()
	t.tween_property(_shot, "modulate:a", 1.0, fade)
	t.tween_property(_shot2, "modulate:a", 0.0, fade)
	t.tween_property(_shot, "scale", Vector2.ONE * zoom1, secs + fade).set_trans(Tween.TRANS_SINE)
	if pan != Vector2.ZERO:
		t.tween_property(_shot, "position", _shot.position + pan * s, secs + fade).set_trans(Tween.TRANS_SINE)
	await _wait(secs)


## Hard cut (fade 0) for action beats.
func _cut(img: String, secs: float, zoom0 := 1.04, zoom1 := 1.0, height := 0.82, tint := NIGHT) -> void:
	await _show(img, secs, zoom0, zoom1, height, 0.0, Vector2.ZERO, tint)


func _lightning(strength := 0.55, near := false) -> void:
	var t := create_tween()
	t.tween_property(_flash, "color:a", strength * 0.6, 0.04)
	t.tween_property(_flash, "color:a", strength * 0.1, 0.07)
	t.tween_property(_flash, "color:a", strength, 0.03)
	t.tween_property(_flash, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_thunder(randf_range(0.05, 0.3) if near else randf_range(0.8, 1.8), near)


func _thunder(delay: float, near: bool) -> void:
	await _wait(delay)
	var path: String = "res://environment/weather/thunder_near.wav" if near else ["res://environment/weather/thunder_far.wav", "res://environment/weather/thunder_roll.wav"].pick_random()
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = thunder_volume_db - (0.0 if near else 6.0)
	p.pitch_scale = randf_range(0.85, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _impact(red := true, shake := 9.0) -> void:
	_shake = shake
	var c := Color(1.0, 0.25, 0.2, 0.7) if red else Color(1, 1, 1, 0.85)
	var t := create_tween()
	_flash.color = Color(c.r, c.g, c.b, c.a)
	t.tween_property(_flash, "color:a", 0.0, 0.25)
	t.tween_callback(func(): _flash.color = Color(0.8, 0.86, 1.0, 0.0))
	# hit-stop: freeze the shot's push-in for a beat
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0


# ------------------------------------------------------------------ the scene
func play() -> void:
	visible = true
	_was_paused = get_tree().paused
	if pause_game:
		get_tree().paused = true
	if _rain_snd.stream:
		_rain_snd.play()
		create_tween().tween_property(_rain_snd, "volume_db", rain_volume_db, 1.5)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 1.2)
	_hint.modulate.a = 0.5
	create_tween().tween_property(_hint, "modulate:a", 0.0, 3.0).set_delay(2.0)

	# 1. enemy view -------------------------------------------------------
	_show("panel_a1", 2.6, 1.0, 1.1, 0.84, 0.01)                  # Nga Tay's back, waiting in the rain
	await _wait(1.0)
	_lightning(0.5)
	await _wait(1.6)
	await _show("panel_a2", 2.6, 1.0, 1.12, 0.84, 0.6)            # MC walks out of the dark
	await _show("panel_b1", 1.9, 1.0, 1.08, 0.84, 0.4)            # raises the blade
	_lightning(0.65, true)
	await _show("panel_b2", 1.6, 1.08, 1.0, 0.84, 0.25)           # his eyes
	await _cut("panel_a3", 0.8, 1.0, 1.08)                        # lunge
	await _cut("panel_b3", 0.45, 1.0, 1.1)
	_impact(false, 6.0)
	await _cut("panel_a4", 0.5, 1.12, 1.0)                        # the blade flashes
	_impact(true, 12.0)
	await _cut("panel_b4", 0.55, 1.0, 1.06)                       # it goes in
	await _cut("panel_b5", 0.8, 1.04, 1.1)
	await _cut("panel_a5", 1.6, 1.0, 1.08)                        # through his chest
	if _done: return
	await _fade_to_black(0.4)

	# 2. isometric: stab, kick, pull out --------------------------------------
	_world(true)
	_show("iso_0", 0.9, 1.0, 1.02, 0.76, 0.01)
	await _fade_from_black(0.35)
	await _wait(0.5)
	await _cut("iso_1", 0.75, 1.0, 1.02, 0.76)
	_impact(false, 10.0)
	await _cut("iso_2", 0.55, 1.03, 1.0, 0.76)                    # kick to the chest
	_impact(true, 7.0)
	_lightning(0.6, true)
	await _cut("iso_3", 1.3, 1.0, 1.03, 0.76)                     # the sword comes out
	if _done: return
	await _show("fall_0", 1.5, 1.0, 1.03, 0.6, 0.3)               # Nga Tay drops to his knees
	_shake = 4.0
	await _show("fall_1", 2.2, 1.0, 1.05, 0.6, 0.45)              # ...and falls face down
	_lightning(0.45)
	await _wait(0.6)
	if _done: return
	await _fade_to_black(0.7)

	# 3. spent: leans on the sword, kneels --------------------------------------
	var k := ["kneel_0", "kneel_1", "kneel_2", "kneel_3", "kneel_4", "kneel_5", "kneel_6", "kneel_7"]
	var dur := [0.9, 0.5, 0.5, 0.6, 0.6, 0.55, 0.7, 2.0]
	_show(k[0], dur[0], 1.0, 1.0, 0.7, 0.01)
	await _fade_from_black(0.5)
	for i in range(1, k.size()):
		if _done: return
		if i == 6:
			_lightning(0.45)
		await _show(k[i], dur[i], 1.0, 1.0, 0.7, 0.18)
	if _done: return

	# 4. close-ups --------------------------------------------------------------
	await _show("portrait", 3.2, 1.0, 1.1, 0.9, 0.9, Vector2.ZERO, Color(0.8, 0.8, 0.92))
	_lightning(0.4)
	await _show("face", 4.2, 1.02, 1.16, 0.95, 1.4, Vector2(0, 0.03), Color(0.82, 0.82, 0.94))
	_end()


## Show the live forest map (paused) behind the shot, dark and rainy; hide the map's own
## MC / bandits there so they don't double up with the cutscene art.
func _world(on: bool) -> void:
	_ground.visible = on
	_bg.visible = not on
	if on and _hidden.is_empty() and get_tree().current_scene:
		for g in ["player", "bandit", "enemy", "boss"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is CanvasItem and n.visible and get_tree().current_scene.is_ancestor_of(n):
					n.visible = false
					_hidden.append(n)
	elif not on:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true
		_hidden.clear()


func _fade_to_black(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	await tw.finished


func _fade_from_black(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, t)
	await tw.finished


func _end() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_fade, "color:a", 1.0, 1.2)
	tw.tween_property(_rain_snd, "volume_db", -40.0, 1.2)
	await tw.finished
	_world(false)
	if pause_game:
		get_tree().paused = _was_paused
	finished.emit()
	queue_free()
