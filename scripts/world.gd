extends Node2D
## Taungoo world. Spawns the chosen top-down character at PlayerSpawn,
## gives them a camera that stays inside the map, and adds the HUD.
## With spawn_player off (title screen) it slowly pans across the city instead.

@export var map_size: Vector2 = Vector2(2048, 1280)
@export var camera_zoom: float = 2.4
## Mouse wheel zooms between these (bigger = closer). Each notch is zoom_step.
@export var zoom_min: float = 1.2
@export var zoom_max: float = 3.0
@export var zoom_step: float = 1.1
@export var spawn_player: bool = true
## How strong the golden morning look is on this map (dry, sandy maps look best lower).
@export_range(0.0, 1.0, 0.05) var morning_strength: float = 1.0
## Set this to play a specific character when you run this scene directly (F6).
@export_enum("village_boy", "black_cat") var test_character: String = ""

var _pan_cam: Camera2D
var _cam: Camera2D
var _shade_vp: SubViewport
var _shade_t := 0.0
var _t := 0.0


func _ready() -> void:
	_setup_light_and_water()
	_apply_clock()
	if not spawn_player:
		_pan_cam = Camera2D.new()
		_pan_cam.zoom = Vector2(1.25, 1.25)
		add_child(_pan_cam)
		_pan_cam.make_current()
		for b in get_tree().get_nodes_in_group("boss"):
			b.set_physics_process(false)
		return
	var key: String = test_character if test_character != "" else Game.topdown_character
	var player: Node2D = load(Game.TOPDOWN[key]).instantiate()
	var spawn: Node2D = $PlayerSpawn
	if Game.next_spawn != "" and has_node(Game.next_spawn):
		spawn = get_node(Game.next_spawn)
	Game.next_spawn = ""
	player.global_position = spawn.global_position
	$Objects.add_child(player)
	_add_sun_shadows(player)
	if Game.camera_zoom > 0.0:  # keep the zoom the player picked on the last map
		camera_zoom = Game.camera_zoom
	camera_zoom = clampf(camera_zoom, zoom_min, zoom_max)
	var cam := Camera2D.new()
	_cam = cam
	cam.name = "Camera2D"
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.position = Vector2(0, -30)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_size.x)
	cam.limit_bottom = int(map_size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)
	cam.make_current()

	var hud := preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.watch_player(player)
	for boss in get_tree().get_nodes_in_group("boss"):
		hud.watch_boss(boss)


func _process(delta: float) -> void:
	_apply_clock()
	# refresh the shadow map ~15 times a second so swaying leaf shadows move on bodies too
	_shade_t -= delta
	if _shade_vp and _shade_t <= 0.0:
		_shade_t = 1.0 / 15.0
		_shade_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _pan_cam == null:
		return
	_t += delta
	# drift along a loop: palace -> market -> fortress gate -> monastery
	var k := _t * 0.035
	_pan_cam.position = Vector2(1000, 620) + Vector2(cos(k) * 520.0, sin(k * 2.0) * 220.0)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if _cam == null or mb == null or not mb.pressed:
		return
	var z := camera_zoom
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		z *= zoom_step
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		z /= zoom_step
	else:
		return
	z = clampf(z, zoom_min, zoom_max)
	# scale the camera by the same ratio, so a house's indoor zoom (camera_zoom * indoor_zoom) is kept
	_cam.zoom *= z / camera_zoom
	camera_zoom = z
	Game.camera_zoom = z
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	Game.reset_world_globals()


## Water map + shadow map for living light, reflections, wading and ripples.
func _setup_light_and_water() -> void:
	if has_node("Water"):
		var w: Sprite2D = $Water
		Game.set_world_water(w.texture, Rect2(w.global_position, w.texture.get_size()))
	_add_sun_shadows(self)
	# --- shadow map: every tree/building/palm cast shadow, drawn once more into a
	# half-size picture of the world (white = sun, dark = shadow). Characters read it,
	# so canopy shadows slide over their bodies as they walk. The copies follow the
	# real shadows as the sun moves (_update_shadows).
	var vp := SubViewport.new()
	vp.name = "ShadeMap"
	vp.size = Vector2i(map_size / 2.0)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(0.5, 0.5))
	_shade_vp = vp
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = map_size
	vp.add_child(bg)
	for cs in find_children("CastShadow", "Sprite2D", true, false):
		if cs.owner and cs.owner.scene_file_path.begins_with("res://characters/"):
			continue
		var d := Sprite2D.new()
		d.texture = cs.texture
		d.centered = cs.centered
		d.offset = cs.offset
		d.flip_h = cs.flip_h
		d.flip_v = cs.flip_v
		d.region_enabled = cs.region_enabled
		d.region_rect = cs.region_rect
		d.material = cs.material
		d.transform = cs.global_transform
		d.modulate = Color(0, 0, 0, clampf(cs.modulate.a * 1.8, 0.0, 0.9))
		vp.add_child(d)
		_shade_copies.append([cs, d])
	Game.set_world_shade(vp.get_texture(), Rect2(Vector2.ZERO, map_size), _shadow_vec(0.3))
	# --- ripples, boat and palm reflections
	var rip := preload("res://scripts/ripples.gd").new()
	rip.name = "Ripples"
	add_child(rip)
	if has_node("Objects"):
		for o in $Objects.get_children():
			if str(o.name).begins_with("Sampan"):
				o.add_to_group("boat")
				Game.add_reflection(o, 14.0)
			elif str(o.name).begins_with("Palm") and o.has_node("Sprite2D"):
				if Game.water_near(o.global_position, 70.0):
					Game.add_reflection(o.get_node("Sprite2D"))


## Light looks: 0 morning / evening, 1 day, 2 night.
## Morning: low golden sun, peachy warm haze, glowing sun beams, soft mist.
const TIMES := {
	0: {"tint": Color(1.0, 0.88, 0.77), "sun": 0.65, "sun_color": Color(1.0, 0.76, 0.52), "shafts": Color(2.4, 1.7, 1.15, 1.0),
		"moon": 0.0, "flies": 0.35, "mist": 1.0, "mist_tint": Color(1.0, 0.9, 0.82),
		"grade": [0.24, 0.09, 1.2, 1.04, 0.26, 0.16, Color(1.0, 0.72, 0.5), 0.6]},
	1: {"tint": Color(0.88, 0.87, 0.84), "sun": 0.5, "sun_color": Color(1, 0.86, 0.66), "shafts": Color(1, 1, 1, 1),
		"moon": 0.0, "flies": 0.35, "mist": 0.0, "mist_tint": Color(1.0, 0.9, 0.82),
		"grade": [0.14, 0.05, 1.06, 1.06, 0.32, 0.06, Color(1.0, 0.8, 0.5), 0.0]},
	2: {"tint": Color(0.32, 0.38, 0.62), "sun": 0.0, "sun_color": Color(1, 0.86, 0.66), "shafts": Color(1, 1, 1, 0),
		"moon": 0.45, "flies": 1.0, "mist": 0.45, "mist_tint": Color(0.6, 0.68, 0.9),
		"grade": [0.14, 0.0, 0.95, 1.06, 0.36, 0.0, Color(0.5, 0.6, 1.0), 0.0]},
}
## Through the day (Game.hour) the light blends between these looks: [hour, look].
const DAY_KEYS := [[0.0, 2], [4.75, 2], [6.25, 0], [9.0, 1], [15.75, 1], [17.75, 0], [19.25, 2], [24.0, 2]]
const GRADE_KEYS := ["bloom", "warmth", "saturation", "contrast", "vignette", "sun_glow", "glow_color", "haze"]
## The sun is up from SUNRISE to SUNSET (and the moon the rest of the night).
const SUNRISE := 5.5
const SUNSET := 18.5
## Highest the sun gets at noon (degrees). Shadows are shortest then.
const SUN_TOP := 72.0
## Longest a shadow gets (x the object's height), at sunrise and sunset.
const SHADOW_MAX := 2.0
## Cast shadow sprites in the scenes are drawn with this length (skew -0.95, y scale ~0.42).
const SHADOW_REF := 0.42
var _mist: CanvasLayer
var _looks := {}
## [shadow sprite, its base scale, its base alpha, x mirror]: every cast shadow.
var _casts: Array = []
## [shadow AnimatedSprite2D, the body it copies]: characters' shadows.
var _anim_casts: Array = []
## [cast shadow, its copy in the shadow map].
var _shade_copies: Array = []


func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in b:
		if key == "grade":
			var g := []
			for i in b.grade.size():
				g.append(lerp(a.grade[i], b.grade[i], k))
			out[key] = g
		else:
			out[key] = lerp(a[key], b[key], k)
	return out


## The light for an hour of the day.
func _light_at(h: float) -> Dictionary:
	if _looks.is_empty():
		_looks = TIMES.duplicate()
		_looks[0] = _mix(TIMES[1], TIMES[0], morning_strength)
	for i in DAY_KEYS.size() - 1:
		var a: Array = DAY_KEYS[i]
		var b: Array = DAY_KEYS[i + 1]
		if h <= b[0]:
			return _mix(_looks[a[1]], _looks[b[1]], smoothstep(a[0], b[0], h))
	return _looks[2]


## Lights the world for Game.hour and turns every shadow to the sun (or moon).
func _apply_clock() -> void:
	var h: float = Game.hour
	var c := _light_at(h)
	if has_node("Atmosphere"):
		$Atmosphere.color = c.tint
	if has_node("Sun"):
		$Sun.energy = c.sun
		$Sun.color = c.sun_color
	if has_node("SunShafts"):
		$SunShafts.modulate = c.shafts
	if has_node("Moon"):
		$Moon.energy = c.moon
	if has_node("Fireflies"):
		$Fireflies.modulate.a = c.flies
	if has_node("Grade/Screen"):
		var m: ShaderMaterial = $Grade/Screen.material
		for i in GRADE_KEYS.size():
			m.set_shader_parameter(GRADE_KEYS[i], c.grade[i])
	_ensure_mist()
	var mm: ShaderMaterial = _mist.get_child(0).material
	mm.set_shader_parameter("amount", c.mist)
	mm.set_shader_parameter("tint", c.mist_tint)
	# shadows: from the sun by day, faint ones from the moon at night
	var sun_f := (h - SUNRISE) / (SUNSET - SUNRISE)
	var moon_f := fposmod(h - SUNSET, 24.0) / (24.0 - SUNSET + SUNRISE)
	var day := sun_f >= 0.0 and sun_f < 1.0
	var f := sun_f if day else moon_f
	var v := _shadow_vec(f)
	var k := smoothstep(0.0, 0.3, sin(PI * f)) * (1.0 if day else 0.3)
	var weather := get_node_or_null("Weather")
	if weather and weather.get("storm") != null:
		k *= 1.0 - 0.8 * float(weather.get("storm"))   # overcast: soft, faint shadows
	# the lights shine the way the shadows fall (normal-mapped shading follows)
	if has_node("Sun"):
		$Sun.rotation = atan2(-_shadow_vec(sun_f).x, _shadow_vec(sun_f).y)
	if has_node("Moon"):
		$Moon.rotation = atan2(-_shadow_vec(moon_f).x, _shadow_vec(moon_f).y)
	RenderingServer.global_shader_parameter_set("shadow_dir", v)
	var grass := get_node_or_null("GrassField")
	if grass and grass.has_method("set_shadow_strength"):
		grass.set_shadow_strength(k)
	_update_shadows(v, k)


## Ground shift of a point 1 px high, i.e. where its shadow falls, for a sun (or moon)
## f of the way across the sky: 0 = rising in the east (shadows long, to the west),
## 0.5 = noon (short, to the north), 1 = setting in the west (long, to the east).
func _shadow_vec(f: float) -> Vector2:
	f = clampf(f, 0.0, 1.0)
	var up := deg_to_rad(SUN_TOP) * sin(PI * f)
	var length := minf(1.0 / maxf(tan(up), 0.01), SHADOW_MAX)
	return Vector2(-cos(PI * f), -sin(PI * f) * 0.5) * length   # ground is squashed 2:1 up/down


## Skews every cast shadow so it falls along v, v.length() times its object's height.
func _update_shadows(v: Vector2, k: float) -> void:
	var len_k := v.length() / SHADOW_REF
	for e in _casts:
		var s: Node2D = e[0]
		if not is_instance_valid(s):
			continue
		s.skew = atan2(v.x * e[3], -v.y)
		s.scale = Vector2(e[1].x, e[1].y * len_k)
		s.modulate.a = e[2] * k
	for e in _anim_casts:
		var sh: AnimatedSprite2D = e[0]
		var b: AnimatedSprite2D = e[1]
		if not is_instance_valid(b):
			continue
		if sh.animation != b.animation:
			sh.animation = b.animation
		sh.frame = b.frame
		sh.flip_h = b.flip_h
		sh.offset = b.offset
		sh.self_modulate.a = b.modulate.a
		sh.visible = b.visible and b.get_parent().z_index <= 0   # no sun indoors
	for e in _shade_copies:
		if is_instance_valid(e[0]):
			e[1].transform = e[0].global_transform
			e[1].modulate.a = clampf(e[0].modulate.a * 1.8, 0.0, 0.9)


## Gives everything under root that has a contact shadow (the round blob under it)
## a cast shadow too, made from its own sprite, and tracks all cast shadows so they
## turn with the sun. Characters get an animated one that copies their frames.
func _add_sun_shadows(root: Node) -> void:
	var blobs := []
	for s in root.find_children("*Shadow", "Sprite2D", true, false):
		if absf(s.skew) > 0.01:
			_track_shadow(s)
		else:
			blobs.append(s)
	for blob in blobs:
		var n: Node = blob.get_parent()
		if _has_cast(n):
			continue
		var body: Node2D = null
		for c in n.get_children():
			if (c is Sprite2D or c is AnimatedSprite2D) and not "Shadow" in str(c.name) and c.name != "Reflection":
				body = c
				break
		if body == null:
			continue
		var cs: Node2D
		if body is AnimatedSprite2D:
			var a := AnimatedSprite2D.new()
			a.name = "SunShadow"
			a.sprite_frames = body.sprite_frames
			a.offset = body.offset
			_anim_casts.append([a, body])
			cs = a
		else:
			var sp := Sprite2D.new()
			sp.name = "CastShadow"
			var tex: Texture2D = body.texture
			sp.texture = tex.diffuse_texture if tex is CanvasTexture else tex
			for p in ["centered", "offset", "flip_h", "flip_v", "hframes", "vframes", "frame", "region_enabled", "region_rect"]:
				sp.set(p, body.get(p))
			cs = sp
		cs.texture_filter = body.texture_filter
		cs.position = body.position
		cs.scale = Vector2(body.scale.x, body.scale.y * SHADOW_REF)
		cs.skew = -0.95
		# under everything standing; a character's own is drawn just before its body
		# instead, so it still shows on yards painted into house / prop sprites
		cs.z_index = 0 if body is AnimatedSprite2D else -1
		cs.modulate = Color(0.04, 0.03, 0.1, 0.3)
		n.add_child(cs)
		n.move_child(cs, 0)
		_track_shadow(cs)


func _has_cast(n: Node) -> bool:
	for c in n.get_children():
		if c is Node2D and "Shadow" in str(c.name) and absf(c.skew) > 0.01:
			return true
	return false


func _track_shadow(s: Node2D) -> void:
	var mirror := signf(s.get_parent().global_transform.x.x) if s.get_parent() is Node2D else 1.0
	_casts.append([s, s.scale, s.modulate.a, mirror if mirror != 0.0 else 1.0])


## Old API, still used by the weather and older scripts. The day clock decides the
## light now, so these just re-apply it.
func apply_time(_t: int, _animate: bool) -> void:
	_apply_clock()


func apply_night(_on: bool, _animate: bool) -> void:
	_apply_clock()


func _ensure_mist() -> void:
	if _mist:
		return
	_mist = CanvasLayer.new()
	_mist.layer = 1
	add_child(_mist)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://environment/fx/mist.gdshader")
	m.set_shader_parameter("amount", 0.0)
	r.material = m
	_mist.add_child(r)


func _physics_process(_delta: float) -> void:
	if _mist:
		var m: ShaderMaterial = _mist.get_child(0).material
		m.set_shader_parameter("cam_pos", -get_viewport().get_canvas_transform().origin / get_viewport().get_canvas_transform().get_scale())
		m.set_shader_parameter("zoom", get_viewport().get_canvas_transform().get_scale().x)
