extends CharacterBody2D
## The MC's mother. 8 directions: walk (8 frames), idle (breathing), cry.
## - Home set: she lives in that house. She starts inside, idling by the hearth.
##   Every Trip Interval seconds she walks to the door, comes down the stairs,
##   idles in the yard for Yard Time, then walks back up and inside to idle again.
##   Inside she is only seen when the player is inside the house too.
## - No Home: walks slowly between Patrol Points (world positions) and waits at each.
## - Stops and turns to the player when the player comes close.
##   An "E" shows over her head then; press it to talk.
## - The first talk is the story intro (the royal summoner is coming), in the
##   dialogue box at the bottom of the screen. Until then a "?" floats over her head.
##   After that she says one line over her head: back from a long time away,
##   bothered twice in a row, the first talk of a night, else one for the time of day.
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
## Her name in the dialogue box.
@export var display_name := "Mother"
## Game hours out of her sight before she greets the player as back from a long trip.
@export var away_hours := 4.0
## Talking to her again within this many game hours is bothering her twice.
@export var repeat_hours := 1.0

const INTRO := [
	"Ah, you're awake. I was beginning to think I'd have to pour water over your head.",
	"Come, sit down. There's rice left from this morning. It won't taste any better if you wait until noon.",
	"And listen, son. The royal summoner is expected in two days.",
	"I don't know what brings him here this time. But when the king calls for men, a village rarely remains the same afterward.",
	"The woman around animal shed comes to know the news. You should seek out for her if you're interested",
]
const MORNING := [
	"Don't spend the whole day wandering, child. There's work to be done around the house.",
	"Have you eaten? There's rice by the fire",
]
const AFTERNOON := [
	"You've been wandering all day. Did you find anything worth seeing, or have you simply been making the same journey around the village?",
]
const NIGHT := [
	"The lamps are lit in every house now. From here, the village looks peaceful, doesn't it? I wish the world beyond it were as peaceful.",
	"Come inside when you're tired. A home should never have to ask its own child to come back.",
]
const NIGHT_GREETING := "I was just about to put the lamp out. Sit for a moment, if you like."
const REPEAT_LINE := "Have you run out of people to bother, or have you come to bother me twice?"
const BACK_LINE := "There you are. I was beginning to wonder whether the forest had swallowed you."

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
var _was_near := false
var _back := false
var _last_line := ""


func _ready() -> void:
	add_to_group("actor")
	add_to_group("npc")
	add_to_group("interactable")
	_bubble = SpeechBubble.new()
	_bubble.head_height = 76.0
	add_child(_bubble)
	if not Game.flags.get("mother_intro_done", false):
		_bubble.mark("?")
	if not Game.flags.has("mother_last_seen"):
		Game.flags["mother_last_seen"] = Game.now()
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
	return not crying and not Game.in_dialogue() and _near(who)


func interact(who: Node2D) -> void:
	_face(who.global_position - global_position)
	if not Game.flags.get("mother_intro_done", false):
		_bubble.mark("")
		Game.dialogue(display_name, PackedStringArray(INTRO), _intro_done)
		return
	_last_line = _pick_line()
	_bubble.say(_last_line)


func _intro_done() -> void:
	Game.flags["mother_intro_done"] = true
	Game.flags["mother_last_talk"] = Game.now()
	_back = false  # she has just seen you


## Which line she says now. Remembers when you last talked (in Game.flags, so leaving
## the village and coming back doesn't reset it).
func _pick_line() -> String:
	var now := Game.now()
	var last: float = Game.flags.get("mother_last_talk", -INF)
	Game.flags["mother_last_talk"] = now
	if _back:
		_back = false
		return BACK_LINE
	if now - last < repeat_hours and _last_line != REPEAT_LINE:
		return REPEAT_LINE
	if Game.time_of_day == 2:
		# a night runs past midnight, so it belongs to the day it started on
		var night := Game.day if Game.hour >= 12.0 else Game.day - 1
		if Game.flags.get("mother_night_greeted", -1) != night:
			Game.flags["mother_night_greeted"] = night
			return NIGHT_GREETING
		return _any(NIGHT)
	return _any(MORNING if Game.hour < 12.0 else AFTERNOON)


## A random line from the list, not the one she just said (when there is another).
func _any(pool: Array) -> String:
	var choices := pool.filter(func(l): return l != _last_line)
	return choices.pick_random() if not choices.is_empty() else pool[0]


## Notices the player coming back after a long time out of her sight.
func _watch_for_return(p: Node2D) -> void:
	var near := _near(p)
	if near and not _was_near and Game.now() - float(Game.flags["mother_last_seen"]) >= away_hours:
		_back = true
	if near:
		Game.flags["mother_last_seen"] = Game.now()
	_was_near = near


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
	_watch_for_return(p)
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
