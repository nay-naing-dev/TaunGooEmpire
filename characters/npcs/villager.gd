extends CharacterBody2D
## Villager with 8 standing directions (PixelLab rotations).
## - Walks between its Patrol Points (world positions) with a little step bob,
##   waits a moment at each one. No points = stands still.
## - Turns to look at you when you come close and stops walking while you talk.

## World positions to walk between, in order (loops back and forth).
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var walk_speed := 20.0
@export var wait_time := 3.0
@export var notice_radius := 60.0
@export var start_facing := "s"

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _i := 0
var _dir := 1
var _wait := 0.0
var _t := 0.0
var _base := 0.0


func _ready() -> void:
	add_to_group("actor")
	_base = sprite.offset.y
	sprite.play(start_facing)
	_wait = randf_range(0.5, wait_time)


func _face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	var d: String = DIRS[wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)]
	if sprite.animation != d:
		sprite.play(d)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var near := p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < notice_radius
	var moving := false
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
				if _i + _dir >= patrol_points.size() or _i + _dir < 0:
					_dir = -_dir
				_i += _dir
			else:
				velocity = d.normalized() * walk_speed
				move_and_slide()
				_face(d)
				moving = true
	# step bob while walking, slow breathing while standing
	if moving:
		sprite.offset.y = _base - absf(sin(_t * 8.0)) * 1.5
		sprite.rotation = sin(_t * 8.0) * 0.025
	else:
		sprite.offset.y = _base - (0.5 + 0.5 * sin(_t * 2.0)) * 0.6
		sprite.rotation = 0.0
