extends CharacterBody2D
## The MC's mother. 8 directions: walk (8 frames), idle (breathing), cry.
## - Home set: she lives in that house. She starts inside, idling by the hearth.
##   Every Trip Interval seconds she walks to the door, comes down the stairs,
##   idles in the yard for Yard Time, then walks back up and inside to idle again.
##   Inside she is only seen when the player is inside the house too.
## - No Home: walks slowly between Patrol Points (world positions) and waits at each.
## - Stops and turns to the player when the player comes close.
##   An "E" shows over her head then; press it and she says one of Lines.
## - crying = true: she stands, hides her face in her hands and sobs.
##   Call set_crying(true / false) from story scripts.

@export var home: NodePath
@export var trip_interval := 180.0
@export var yard_time := 20.0
## Where she idles inside, relative to the house's Inside node (the room floor).
@export var hearth_spot := Vector2(60, 104)
## Where she idles outside, relative to the house origin (the foot of its stairs).
@export var yard_spot := Vector2(70, 50)
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var walk_speed := 22.0
@export var wait_time := 4.0
@export var notice_radius := 64.0
@export var start_facing := "s"
@export var crying := false
## What she says when you talk to her (one at random each time).
@export var lines: PackedStringArray = PackedStringArray([
	"Have you eaten my son? There's rice by the fire.",
	"Check in on your aunt. I've heard she's not well.",
])

const SpeechBubble := preload("res://scripts/speech_bubble.gd")
enum Trip { INSIDE, TO_DOOR, TO_YARD, YARD, TO_STAIRS, TO_HEARTH }
const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "s"
var _i := 0
var _step := 1
var _wait := 0.0
var _t := 0.0
var _base := Vector2.ZERO
var _house: Node2D
var _trip := Trip.INSIDE
var _clock := 0.0
var _leg_t := 0.0
var _inside := false
var _layer := 1
var _bubble: SpeechBubble


func _ready() -> void:
	add_to_group("actor")
	add_to_group("npc")
	add_to_group("interactable")
	_bubble = SpeechBubble.new()
	_bubble.head_height = 76.0
	add_child(_bubble)
	_base = sprite.offset
	_layer = collision_layer
	facing = start_facing
	_wait = randf_range(0.5, wait_time)
	_house = get_node_or_null(home) as Node2D
	if _house:
		global_position = _hearth()
		_set_inside(true)
	_play("cry" if crying else "idle")


func set_crying(on: bool) -> void:
	crying = on
	_play("cry" if on else "idle")


func _near(p: Node2D) -> bool:
	return visible and p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < notice_radius


## Game.interact() asks these when the player presses E.
func can_interact(who: Node2D) -> bool:
	return not crying and not lines.is_empty() and _near(who)


func interact(who: Node2D) -> void:
	_face(who.global_position - global_position)
	_bubble.say(lines[randi() % lines.size()])


func _play(kind: String) -> void:
	var anim := "%s_%s" % [kind, facing]
	if sprite.animation != anim:
		var keep := sprite.frame if kind == "walk" and sprite.animation.begins_with("walk") else 0
		sprite.play(anim)
		sprite.frame = keep


func _face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	facing = DIRS[wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)]


func _hearth() -> Vector2:
	return _house.get_node("Inside").to_global(hearth_spot)


func _door() -> Vector2:
	return _house.get_node("Inside/DoorIn").global_position + Vector2(0, -4)


func _stairs() -> Vector2:
	return _house.global_position + Vector2(0, 12)


## Inside she shares the furniture's layer, like the player does in house.gd.
func _set_inside(on: bool) -> void:
	_inside = on
	z_index = 41 if on else 0


## Walks toward target; true once there. Inside the room she slides freely
## (the walls only exist while the player is inside), outside she uses physics.
func _walk_to(target: Vector2, delta: float) -> bool:
	var d := target - global_position
	_leg_t += delta
	if d.length() < 2.0 or _leg_t > 30.0:  # 30 s: stuck on something, just arrive
		global_position = target if d.length() >= 2.0 else global_position
		_leg_t = 0.0
		return true
	_face(d)
	var v := d.normalized() * walk_speed * Vector2(1.0, 0.75)
	if _inside:
		global_position += (v * delta).limit_length(d.length())
	else:
		velocity = v
		move_and_slide()
	return false


## Home routine, one frame. Returns true while she is walking.
func _home_step(delta: float) -> bool:
	_clock += delta
	match _trip:
		Trip.INSIDE:
			if _clock >= trip_interval:
				_clock = 0.0
				_trip = Trip.TO_DOOR
		Trip.TO_DOOR:
			if _walk_to(_door(), delta):
				_set_inside(false)
				global_position = _stairs()
				_trip = Trip.TO_YARD
			return true
		Trip.TO_YARD:
			if _walk_to(_house.global_position + yard_spot, delta):
				_wait = yard_time
				_trip = Trip.YARD
			return true
		Trip.YARD:
			_wait -= delta
			if _wait <= 0.0:
				_trip = Trip.TO_STAIRS
		Trip.TO_STAIRS:
			if _walk_to(_stairs(), delta):
				_set_inside(true)
				global_position = _door()
				_trip = Trip.TO_HEARTH
			return true
		Trip.TO_HEARTH:
			if _walk_to(_hearth(), delta):
				facing = start_facing
				_trip = Trip.INSIDE
			return true
	return false


func _physics_process(delta: float) -> void:
	_t += delta
	if _house:
		# inside the room she is only there for a player who is in the room too
		visible = not _inside or _house.is_inside
		collision_layer = _layer if visible else 0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_bubble.hint(p != null and can_interact(p))
	if crying:
		# shoulders shake with each sob, now and then a deeper breath
		var sob := maxf(0.0, sin(_t * 9.0)) * (0.6 + 0.4 * sin(_t * 0.7))
		sprite.offset = _base + Vector2(sin(_t * 23.0) * 0.25 * sob, -sob * 1.2)
		_play("cry")
		return
	var moving := false
	if _near(p):
		_face(p.global_position - global_position)
	elif _bubble.is_talking():
		pass  # finish the sentence before walking off
	elif _house:
		moving = _home_step(delta)
	elif patrol_points.size() > 1:
		if _wait > 0.0:
			_wait -= delta
		else:
			var target := patrol_points[_i]
			var d := target - global_position
			if d.length() < 2.0:
				_wait = wait_time
				if _i + _step >= patrol_points.size() or _i + _step < 0:
					_step = -_step
				_i += _step
			else:
				velocity = d.normalized() * walk_speed * Vector2(1.0, 0.75)
				move_and_slide()
				_face(d)
				moving = true
	if moving:
		_play("walk")
		sprite.offset = _base + Vector2(0, -absf(sin(_t * 9.0)) * 0.6)
	else:
		_play("idle")
		sprite.offset = _base + Vector2(0, -(0.5 + 0.5 * sin(_t * 1.8)) * 0.8)   # slow breathing
