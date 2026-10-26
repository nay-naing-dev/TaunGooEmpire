extends CharacterBody2D
## Townsperson who strolls between random spots near where you placed them,
## pauses, looks around, and walks on. Uses the same 8-direction animation
## names as the player: idle_<dir> and walk_<dir> (falls back to run_<dir>).

@export var move_speed: float = 28.0
## How far from the start point they wander (pixels).
@export var wander_radius: float = 90.0
@export var pause_min: float = 1.5
@export var pause_max: float = 4.0

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _home: Vector2
var _target: Vector2
var _wait := 0.0
var _facing := 2


func _ready() -> void:
	_home = global_position
	_target = _home
	_wait = randf_range(0.0, pause_max)


func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		if _wait <= 0.0:
			var a := randf() * TAU
			_target = _home + Vector2(cos(a), sin(a) * 0.5) * randf_range(20.0, wander_radius)
	else:
		var to := _target - global_position
		if to.length() < 3.0:
			_wait = randf_range(pause_min, pause_max)
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * move_speed
			# undo the iso squash to find the facing on the ground
			var g := Vector2(to.x, to.y * 2.0)
			_facing = wrapi(roundi(g.angle() / (TAU / 8.0)), 0, 8)
	var before := global_position
	move_and_slide()
	if velocity != Vector2.ZERO and global_position.distance_to(before) < 0.05:
		_wait = randf_range(pause_min, pause_max)      # bumped into something: stop
	_play("walk" if velocity.length() > 1.0 else "idle")


func _play(base: String) -> void:
	var name := "%s_%s" % [base, DIRS[_facing]]
	if not sprite.sprite_frames.has_animation(name):
		name = "run_%s" % DIRS[_facing]
	if sprite.animation != name:
		sprite.play(name)
