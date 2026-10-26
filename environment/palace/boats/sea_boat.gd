extends Node2D
## Boat on the sea, 8 directions. Sails along its route (world points, loops),
## turns to face where it is going, bobs and rocks on the swell.

@export var route: PackedVector2Array = PackedVector2Array()
@export var speed := 14.0
@export var pause_time := 3.0
@export var facing := "w"

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _i := 0
var _wait := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("actor")
	_t = randf() * 10.0
	sprite.play(facing)


func _process(delta: float) -> void:
	_t += delta
	sprite.offset.y = sin(_t * 1.3) * 1.2
	sprite.rotation = sin(_t * 0.9) * 0.012
	if route.size() < 2:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var d := route[_i] - global_position
	if d.length() < 3.0:
		_i = (_i + 1) % route.size()
		_wait = pause_time
		return
	global_position += d.normalized() * speed * delta
	var a := Vector2(d.x, d.y * 2.0).angle()
	var f: String = DIRS[wrapi(roundi(a / (TAU / 8.0)), 0, 8)]
	if f != sprite.animation:
		sprite.play(f)
