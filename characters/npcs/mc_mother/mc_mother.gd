extends CharacterBody2D
## The MC's mother. 8 directions: walk (8 frames), idle (breathing), cry.
## - Walks slowly between Patrol Points (world positions) and waits at each.
## - Stops and turns to the player when the player comes close.
## - crying = true: she stands, hides her face in her hands and sobs.
##   Call set_crying(true / false) from story scripts.

@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var walk_speed := 22.0
@export var wait_time := 4.0
@export var notice_radius := 64.0
@export var start_facing := "s"
@export var crying := false

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "s"
var _i := 0
var _step := 1
var _wait := 0.0
var _t := 0.0
var _base := Vector2.ZERO


func _ready() -> void:
	add_to_group("actor")
	add_to_group("npc")
	_base = sprite.offset
	facing = start_facing
	_wait = randf_range(0.5, wait_time)
	_play("cry" if crying else "idle")


func set_crying(on: bool) -> void:
	crying = on
	_play("cry" if on else "idle")


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


func _physics_process(delta: float) -> void:
	_t += delta
	var moving := false
	if crying:
		# shoulders shake with each sob, now and then a deeper breath
		var sob := maxf(0.0, sin(_t * 9.0)) * (0.6 + 0.4 * sin(_t * 0.7))
		sprite.offset = _base + Vector2(sin(_t * 23.0) * 0.25 * sob, -sob * 1.2)
		_play("cry")
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var near := p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < notice_radius
	if near:
		_face(p.global_position - global_position)
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
