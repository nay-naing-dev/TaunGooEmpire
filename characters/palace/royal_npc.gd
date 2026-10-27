extends CharacterBody2D
## Palace character (king, guards, archers, flag bearers, ladies, trainer,
## cavalry, elephants, horses). 8 directions.
## - idle_anim: "idle" (stands, breathing) or e.g. "train" (trainer demonstrates).
## - Patrol Points: walks between them (uses "walk_<dir>" if the character has it,
##   otherwise glides with a step bob).
## - look_at_player: turns toward the MC when he comes close (guards keep their post).

@export var start_facing := "s"
@export var idle_anim := "idle"
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var walk_speed := 18.0
@export var wait_time := 3.0
@export var look_at_player := false
@export var notice_radius := 70.0
@export var breathe := 0.7

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
	facing = start_facing
	_base = sprite.offset
	_t = randf() * 10.0
	_wait = randf_range(0.5, wait_time)
	_play(idle_anim)
	if sprite.sprite_frames.get_frame_count(sprite.animation) > 1:
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(sprite.animation)


func _play(kind: String) -> void:
	var a := "%s_%s" % [kind, facing]
	if not sprite.sprite_frames.has_animation(a):
		a = "idle_" + facing
	if sprite.animation != a:
		sprite.play(a)
	elif not sprite.is_playing():
		sprite.play()


func _face(v: Vector2) -> void:
	if v.length() > 0.01:
		facing = DIRS[wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)]


func _physics_process(delta: float) -> void:
	_t += delta
	var moving := false
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if look_at_player and p and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < notice_radius:
		_face(p.global_position - global_position)
	elif patrol_points.size() > 1:
		if _wait > 0.0:
			_wait -= delta
		else:
			var d := patrol_points[_i] - global_position
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
		if not sprite.sprite_frames.has_animation("walk_" + facing):
			sprite.offset = _base + Vector2(0, -absf(sin(_t * 7.0)) * 1.2)
		else:
			sprite.offset = _base
	else:
		_play(idle_anim)
		sprite.offset = _base + Vector2(0, -(0.5 + 0.5 * sin(_t * 1.7)) * breathe)
