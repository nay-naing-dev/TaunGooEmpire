extends Node
## Autoload "Game": remembers which character you picked and switches scenes.
## Press Esc anywhere to go back to the title screen.

const TOPDOWN := {
	"village_boy": "res://characters/topdown/hero2/hero2.tscn",
	"black_cat": "res://characters/topdown/black_cat/black_cat.tscn",
}
const TITLE := "res://scenes/title/title_screen.tscn"
const WORLD := "res://scenes/world/taungoo_world.tscn"
const VILLAGE := "res://scenes/village/village.tscn"
const FOREST := "res://scenes/forest/forest_road.tscn"

var topdown_character := "village_boy"
## What NPCs call the player ("{player}" in their lines).
var player_name := "Player"
## F2 toggles ASCII-art graphics, F3 skips to the next morning / day / night.
var ascii_mode := false
var night_mode := false
## True while the player is inside a house (rain hides, etc).
var indoors := false
## Camera zoom picked with the mouse wheel (world.gd); 0 = the map's own default.
var camera_zoom := 0.0
## Marker2D name to arrive at in the next map (set by map exits).
var next_spawn := ""
## Day clock: the hour of the day, 0..24. A whole day takes day_length real seconds,
## and worlds light themselves (and turn their shadows) from it every frame.
var hour := 7.0
## Day number, counting from 1. Goes up each time the clock passes midnight.
var day := 1
var day_length := 600.0
var clock_running := true
## Which part of the day `hour` is in: 0 = morning / evening (golden), 1 = day, 2 = night.
## F3 skips ahead to the next one.
var time_of_day := 0
const TIME_NAMES := ["Morning", "Day", "Night"]
## The hour F3 skips to for each part of the day.
const TIME_HOURS := [6.5, 12.0, 21.0]
var _skip: Tween
## Story state that outlives a scene change (quests, who you have talked to, ...).
var flags: Dictionary = {}
const DIALOGUE_BOX := preload("res://scripts/dialogue_box.gd")
var _dialogue: CanvasLayer
var _ascii_layer: CanvasLayer
## In ASCII mode, draw the player and bosses as normal sprites on top so they stay readable.
var ascii_keep_characters_clear := true
var _clear_layer: CanvasLayer
var _moved: Dictionary = {}

## Living light: every character sprite gets rounded body shading, rim light and
## tree shadows sliding over it (environment/fx/lit_character.gdshader).
var living_light := true
## Characters, boats and palms near water get a rippling reflection.
var water_reflections := true
const LIT_SHADER := preload("res://environment/fx/lit_character.gdshader")
const REFLECT_SHADER := preload("res://environment/fx/water_reflection.gdshader")
const REFLECTION := preload("res://scripts/reflection.gd")
var _lit_canvas: ShaderMaterial
var _lit_sheets: Dictionary = {}
var _reflect_mat: ShaderMaterial
var _white: ImageTexture
var _no_water: ImageTexture
## The current world's water (set by world.gd). Used for wading, reflections, ripples.
var water_image: Image
var water_rect := Rect2()


func _ready() -> void:
	_ascii_layer = CanvasLayer.new()
	_ascii_layer.layer = 4                    # above the world, below menus / HUD
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://environment/fx/ascii/ascii.gdshader")
	mat.set_shader_parameter("glyphs", load("res://environment/fx/ascii/glyphs.png"))
	rect.material = mat
	_ascii_layer.add_child(rect)
	_ascii_layer.visible = ascii_mode
	add_child(_ascii_layer)
	_clear_layer = CanvasLayer.new()
	_clear_layer.layer = 4
	_clear_layer.follow_viewport_enabled = true
	add_child(_clear_layer)
	get_tree().node_added.connect(_on_node_added)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_no_water = ImageTexture.create_from_image(img)
	_lit_canvas = ShaderMaterial.new()
	_lit_canvas.shader = LIT_SHADER
	_reflect_mat = ShaderMaterial.new()
	_reflect_mat.shader = REFLECT_SHADER
	reset_world_globals()


func set_ascii(on: bool) -> void:
	ascii_mode = on
	_ascii_layer.visible = on
	_sync_clear_characters()


func _on_node_added(n: Node) -> void:
	if ascii_mode and (n.is_in_group("player") or n.is_in_group("boss")):
		_sync_clear_characters.call_deferred()
	if n is AnimatedSprite2D or n is Sprite2D:
		_light_up.call_deferred(n)


# ---------------------------------------------------------------- living light

## Gives a character sprite the living-light material (and a water reflection).
## Works for any sprite inside a scene saved under res://characters/ whose frames
## have a normal map (CanvasTexture, or a sheet with a matching *_n.png).
func _light_up(n) -> void:
	if not is_instance_valid(n) or n.has_meta("lit") or not n.is_inside_tree():
		return
	if n.owner == null or not n.owner.scene_file_path.begins_with("res://characters/"):
		return
	if "Shadow" in str(n.name) or n.get_script() == REFLECTION:
		return
	n.set_meta("lit", true)
	var tex: Texture2D = null
	if n is Sprite2D:
		tex = n.texture
	elif n.sprite_frames != null and n.sprite_frames.has_animation(n.animation):
		tex = n.sprite_frames.get_frame_texture(n.animation, n.frame)
	if living_light and n.material == null and tex != null:
		if tex is CanvasTexture and tex.normal_texture != null:
			n.material = _lit_canvas
		elif tex is AtlasTexture and tex.atlas != null:
			var np: String = tex.atlas.resource_path.get_basename() + "_n.png"
			if ResourceLoader.exists(np):
				if not _lit_sheets.has(np):
					var m := ShaderMaterial.new()
					m.shader = LIT_SHADER
					m.set_shader_parameter("use_sheet", true)
					m.set_shader_parameter("normal_sheet", load(np))
					_lit_sheets[np] = m
				n.material = _lit_sheets[np]
	# the main body sprite (direct child of the character) gets a reflection
	if n.material != null and n.get_parent() == n.owner:
		add_reflection(n)


## Adds a rippling upside-down copy of `src` that shows only on water.
## mirror_y: where the water line is, in src's local pixels (0 = at its origin / feet).
func add_reflection(src: CanvasItem, mirror_y: float = 0.0) -> void:
	if not water_reflections or src.has_meta("reflected"):
		return
	src.set_meta("reflected", true)
	var r := Sprite2D.new()
	r.set_script(REFLECTION)
	r.name = "Reflection"
	r.set("src", src)
	r.set("mirror_y", mirror_y)
	r.material = _reflect_mat
	src.get_parent().add_child(r)


func reset_world_globals() -> void:
	RenderingServer.global_shader_parameter_set("world_shade", _white)
	RenderingServer.global_shader_parameter_set("world_shade_rect", Vector4(0, 0, 1, 1))
	RenderingServer.global_shader_parameter_set("world_water", _no_water)
	RenderingServer.global_shader_parameter_set("world_water_rect", Vector4(0, 0, 1, 1))
	water_image = null


func set_world_water(tex: Texture2D, rect: Rect2) -> void:
	water_image = tex.get_image()
	if water_image.is_compressed():
		water_image.decompress()
	water_rect = rect
	RenderingServer.global_shader_parameter_set("world_water", tex)
	RenderingServer.global_shader_parameter_set("world_water_rect",
			Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func set_world_shade(tex: Texture2D, rect: Rect2, shadow_dir: Vector2) -> void:
	RenderingServer.global_shader_parameter_set("world_shade", tex)
	RenderingServer.global_shader_parameter_set("world_shade_rect",
			Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	RenderingServer.global_shader_parameter_set("shadow_dir", shadow_dir)


## Water depth at a world position: -1 = dry land, 0 = shore .. 1 = deep.
func water_depth(p: Vector2) -> float:
	if water_image == null:
		return -1.0
	var q := Vector2i((p - water_rect.position).floor())
	if q.x < 0 or q.y < 0 or q.x >= water_image.get_width() or q.y >= water_image.get_height():
		return -1.0
	var c := water_image.get_pixelv(q)
	return c.r if c.a > 0.5 else -1.0


func is_water(p: Vector2) -> bool:
	return water_depth(p) >= 0.0


## True when there is water within `reach` pixels below p (where a reflection would show).
func water_near(p: Vector2, reach: float) -> bool:
	return is_water(p + Vector2(0, 3)) or is_water(p + Vector2(0, reach * 0.45)) \
			or is_water(p + Vector2(0, reach * 0.9))


## Moves characters above the ASCII filter (or back into the world).
func _sync_clear_characters() -> void:
	var want := ascii_mode and ascii_keep_characters_clear
	if want:
		for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("boss"):
			if not _moved.has(n) and n.get_parent() != _clear_layer and n.is_inside_tree():
				_moved[n] = n.get_parent()
				n.reparent(_clear_layer, true)
	else:
		for n in _moved.keys():
			if is_instance_valid(n) and is_instance_valid(_moved[n]):
				n.reparent(_moved[n], true)
		_moved.clear()


func _process(delta: float) -> void:
	if clock_running and not (_skip and _skip.is_running()):
		set_hour(hour + delta * 24.0 / day_length)


func set_hour(h: float) -> void:
	var next := fposmod(h, 24.0)
	if next < hour - 12.0:  # passed midnight
		day += 1
	hour = next
	if hour >= 19.0 or hour < 5.0:
		time_of_day = 2
	elif hour >= 9.0 and hour < 16.5:
		time_of_day = 1
	else:
		time_of_day = 0
	night_mode = time_of_day == 2


## Fast-forwards the clock (over 2 s) to the start of part t of the day.
func set_time(t: int) -> void:
	var target: float = TIME_HOURS[wrapi(t, 0, 3)]
	if target <= hour:
		target += 24.0
	if _skip:
		_skip.kill()
	_skip = create_tween()
	_skip.tween_method(set_hour, hour, target, 2.0).set_trans(Tween.TRANS_SINE)


func set_night(on: bool) -> void:
	set_time(2 if on else 0)


## Game hours since the start of day 0 (keeps counting past midnight), for "how long ago" checks.
func now() -> float:
	return day * 24.0 + hour


## Opens the dialogue box at the bottom of the screen with the speaker's name and
## their lines, one after another. done is called after the last one.
## With choices, the player picks one under the last line and done(index) is called.
func dialogue(speaker: String, lines: PackedStringArray, done := Callable(), choices := PackedStringArray()) -> void:
	if _dialogue == null:
		_dialogue = DIALOGUE_BOX.new()
		add_child(_dialogue)
	_dialogue.open(speaker, lines, done, choices)


## True while the dialogue box is up (players stand still and E only turns its pages).
func in_dialogue() -> bool:
	return _dialogue != null and _dialogue.busy()


func go(scene_path: String) -> void:
	indoors = false
	if _dialogue:
		_dialogue.close(false)
	for n in _moved.keys():
		if is_instance_valid(n):
			n.queue_free()
	_moved.clear()
	get_tree().change_scene_to_file(scene_path)


## E: talk to / use the closest node in group "interactable" that is in reach of who
## (it decides with can_interact(who), then gets interact(who)).
## False when nothing is in reach, so the player can do its own E thing instead.
func interact(who: Node2D) -> bool:
	var best: Node2D = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.can_interact(who) and (best == null or who.global_position.distance_to(n.global_position) < who.global_position.distance_to(best.global_position)):
			best = n
	if best:
		best.interact(who)
	return best != null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			set_ascii(not ascii_mode)
		elif event.keycode == KEY_F3:
			set_time(time_of_day + 1)
	if event.is_action_pressed("ui_cancel") and get_tree().current_scene \
			and get_tree().current_scene.scene_file_path != TITLE:
		go(TITLE)
