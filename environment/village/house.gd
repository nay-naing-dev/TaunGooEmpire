extends Node2D
## Village house you can walk into (bamboo / plank stilt houses).
## - Outside: the house with its roof. It turns see-through when you walk behind it.
## - Walk up its stairs (the node's origin is the foot of the stairs) and keep moving
##   up: the screen dips to black and the roof comes off - you are inside the room,
##   the rest of the village is dimmed, a warm hearth light glows (stronger at night).
## - Inside, every piece of furniture is its own object: walk around the bed,
##   behind the table... The walls keep you on the floor.
## - Walk back to the top of the stairs and press down to go outside again.

@export var enterable := true
@export var enter_radius := 26.0
@export var exit_radius := 22.0
@export_range(0.0, 1.0, 0.05) var faded_alpha := 0.45
## Zoom the camera in a little while indoors (1 = no change).
@export var indoor_zoom := 1.2

@onready var outside: StaticBody2D = $Outside
@onready var inside: Node2D = $Inside
@onready var ext_sprite: Sprite2D = $Outside/Sprite2D
var is_inside := false
var _busy := false
var _fade: ColorRect


func _ready() -> void:
	add_to_group("house")
	_set_furniture_solid(false)


## Furniture only blocks you while you are inside this house.
func _set_furniture_solid(on: bool) -> void:
	if not has_node("Inside/Furniture"):
		return
	for f in $Inside/Furniture.get_children():
		if f is CollisionObject2D:
			f.collision_layer = 1 if on else 0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	var p := _player()
	if p == null or _busy or Game.cutscene:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not is_inside:
		if enterable and input.y < -0.3 and _ground_dist(p.global_position, global_position) < enter_radius:
			_switch(true)
		# see-through when the player is behind the house
		var local := to_local(p.global_position)
		var target := 1.0
		if local.y < -6.0 and ext_sprite.get_rect().grow(-12).has_point(local + Vector2(0, -20)):
			target = faded_alpha
		ext_sprite.modulate.a = move_toward(ext_sprite.modulate.a, target, delta * 4.0)
	else:
		var door: Vector2 = $Inside/DoorIn.global_position
		if input.y > 0.3 and _ground_dist(p.global_position, door) < exit_radius:
			_switch(false)
		var night: bool = Game.get("time_of_day") == 2
		$Inside/HearthLight.energy = lerpf($Inside/HearthLight.energy, 1.5 if night else 0.55, delta * 2.0)


func _ground_dist(a: Vector2, b: Vector2) -> float:
	return Vector2(a.x - b.x, (a.y - b.y) * 1.6).length()


func _switch(enter: bool) -> void:
	_busy = true
	var p := _player()
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 9
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.18)
	await t.finished
	_go(enter, p)
	await get_tree().physics_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.25)
	await t2.finished
	_busy = false


## Story scenes: puts the player outside right away (no fade of its own).
func leave_now() -> void:
	if is_inside:
		_go(false, _player())


func _go(enter: bool, p: Node2D) -> void:
	is_inside = enter
	Game.set("indoors", enter)
	outside.visible = not enter
	$Outside/CollisionPolygon2D.set_deferred("disabled", enter)
	inside.visible = enter
	$Inside/Walls/CollisionPolygon2D.set_deferred("disabled", not enter)
	_set_furniture_solid(enter)
	if p:
		p.velocity = Vector2.ZERO
		if enter:
			p.global_position = $Inside/DoorIn.global_position + Vector2(0, -4)
			p.z_index = 41  # same layer as the furniture -> walk in front of / behind it
		else:
			p.global_position = global_position + Vector2(0, 12)
			p.z_index = 0
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			var z: float = get_tree().current_scene.get("camera_zoom") if get_tree().current_scene.get("camera_zoom") else cam.zoom.x
			cam.zoom = Vector2.ONE * (z * indoor_zoom if enter else z)
			cam.reset_smoothing()
