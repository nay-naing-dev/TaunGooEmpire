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
	apply_time(Game.time_of_day, false)
	_setup_light_and_water()
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
	# --- shadow map: every tree/building/palm cast shadow, drawn once more into a
	# half-size picture of the world (white = sun, dark = shadow). Characters read it,
	# so canopy shadows slide over their bodies as they walk.
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
	var dir := Vector2(-0.4, -0.3)
	var found := false
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
		if not found and cs.owner and "forest" in cs.owner.scene_file_path:
			var ps: float = cs.get_parent().global_scale.y
			dir = cs.global_transform.basis_xform(Vector2(0, -1)) / maxf(ps, 0.01)
			found = true
	Game.set_world_shade(vp.get_texture(), Rect2(Vector2.ZERO, map_size), dir)
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


## Light for the time of day: 0 morning, 1 day, 2 night.
## Morning: low golden sun, peachy warm haze, glowing sun beams, soft mist.
const TIMES := {
	0: {"tint": Color(1.0, 0.88, 0.77), "sun": 0.65, "sun_color": Color(1.0, 0.76, 0.52), "shafts": Color(2.4, 1.7, 1.15, 1.0),
		"moon": 0.0, "flies": 0.35, "mist": 1.0, "grade": [0.24, 0.09, 1.2, 1.04, 0.26, 0.16, Color(1.0, 0.72, 0.5), 0.6]},
	1: {"tint": Color(0.88, 0.87, 0.84), "sun": 0.5, "sun_color": Color(1, 0.86, 0.66), "shafts": Color(1, 1, 1, 1),
		"moon": 0.0, "flies": 0.35, "mist": 0.0, "grade": [0.14, 0.05, 1.06, 1.06, 0.32, 0.06, Color(1.0, 0.8, 0.5), 0.0]},
	2: {"tint": Color(0.32, 0.38, 0.62), "sun": 0.0, "sun_color": Color(1, 0.86, 0.66), "shafts": Color(1, 1, 1, 0),
		"moon": 0.45, "flies": 1.0, "mist": 0.45, "grade": [0.14, 0.0, 0.95, 1.06, 0.36, 0.0, Color(0.5, 0.6, 1.0), 0.0]},
}
var _mist: CanvasLayer


func _blend_morning(k: float) -> Dictionary:
	var a: Dictionary = TIMES[1]
	var b: Dictionary = TIMES[0]
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


func apply_time(t: int, animate: bool) -> void:
	var c: Dictionary = TIMES[clampi(t, 0, 2)]
	if t == 0 and morning_strength < 1.0:
		c = _blend_morning(morning_strength)
	var d := 2.0 if animate else 0.0
	var tw := create_tween().set_parallel()
	if has_node("Atmosphere"):
		tw.tween_property($Atmosphere, "color", c.tint, d)
	if has_node("Sun"):
		tw.tween_property($Sun, "energy", c.sun, d)
		tw.tween_property($Sun, "color", c.sun_color, d)
	if has_node("SunShafts"):
		tw.tween_property($SunShafts, "modulate", c.shafts, d)
	if has_node("Moon"):
		tw.tween_property($Moon, "energy", c.moon, d)
	if has_node("Fireflies"):
		$Fireflies.modulate.a = c.flies
	if has_node("Grade/Screen"):
		var m: ShaderMaterial = $Grade/Screen.material
		var g: Array = c.grade
		var keys := ["bloom", "warmth", "saturation", "contrast", "vignette", "sun_glow", "glow_color", "haze"]
		for i in keys.size():
			var from = m.get_shader_parameter(keys[i])
			if from == null:
				m.set_shader_parameter(keys[i], g[i])
			else:
				var k: String = keys[i]
				tw.tween_method(func(v): m.set_shader_parameter(k, v), from, g[i], d)
	_ensure_mist()
	var mm: ShaderMaterial = _mist.get_child(0).material
	tw.tween_method(func(v): mm.set_shader_parameter("amount", v), float(mm.get_shader_parameter("amount")), c.mist, d)
	mm.set_shader_parameter("tint", Color(1.0, 0.9, 0.82) if t != 2 else Color(0.6, 0.68, 0.9))


## Old name, still used by the weather and older scripts.
func apply_night(on: bool, animate: bool) -> void:
	apply_time(2 if on else (Game.time_of_day if Game.time_of_day != 2 else 0), animate)


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
