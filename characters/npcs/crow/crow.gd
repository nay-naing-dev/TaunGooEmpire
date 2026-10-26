extends Node2D
## Crow: hops and pecks around its home spot, takes off when you come close,
## flies a few seconds and lands somewhere else nearby. Now and then it flies
## a short loop by itself. Flying crows reflect in water and cast a shadow below.

@export var home_radius := 150.0
## Fly away when the player (or boss) comes this close.
@export var flee_distance := 60.0
@export var walk_speed := 16.0
@export var fly_speed := 95.0
@export var max_height := 60.0

enum S { IDLE, WALK, FLY }
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow

var state := S.IDLE
var home: Vector2
var target: Vector2
var height := 0.0
var _timer := 1.0
var _from: Vector2
var _fly_total := 1.0
var _base_off := 0.0
var _base_shadow := Vector2.ONE


func _ready() -> void:
	add_to_group("actor")
	home = global_position
	_base_off = sprite.offset.y
	_base_shadow = shadow.scale
	_timer = randf_range(0.5, 3.0)
	sprite.play("idle")
	sprite.frame = 0


func _process(delta: float) -> void:
	_timer -= delta
	var threat := _threat()
	match state:
		S.IDLE:
			# peck: dip the head now and then
			sprite.rotation = 0.25 * maxf(0.0, sin(Time.get_ticks_msec() * 0.012 + home.x)) if fmod(_timer, 1.6) < 0.3 else 0.0
			if threat:
				_take_off(threat)
			elif _timer <= 0.0:
				if randf() < 0.15:
					_take_off(null)
				else:
					target = _ground_point(global_position, 40.0)
					state = S.WALK
					sprite.rotation = 0.0
					sprite.play("walk")
		S.WALK:
			var d := target - global_position
			if threat:
				_take_off(threat)
			elif d.length() < 2.0:
				state = S.IDLE
				_timer = randf_range(1.0, 4.0)
				sprite.play("idle")
			else:
				global_position += d.normalized() * walk_speed * delta
				sprite.flip_h = d.x < 0.0
		S.FLY:
			var u := clampf(1.0 - _from.distance_to(global_position) / maxf(_fly_total, 1.0), 0.0, 1.0)
			var d := target - global_position
			if d.length() < 3.0:
				state = S.IDLE
				height = 0.0
				_timer = randf_range(2.0, 6.0)
				sprite.play("idle")
			else:
				global_position += d.normalized() * minf(fly_speed * delta, d.length())
				sprite.flip_h = d.x < 0.0
				var prog := 1.0 - d.length() / maxf(_fly_total, 1.0)
				height = max_height * sin(PI * clampf(prog, 0.0, 1.0))
				# flap going up, glide coming down
				var want := "fly" if prog < 0.55 or prog > 0.9 else "glide"
				if sprite.animation != want:
					sprite.play(want)
	sprite.offset.y = _base_off - height / maxf(sprite.scale.y, 0.01)
	var k := clampf(1.0 - height / (max_height * 1.6), 0.35, 1.0)
	shadow.scale = _base_shadow * k
	shadow.modulate.a = 0.45 * k


func _threat() -> Node2D:
	for g in ["player", "boss"]:
		for n in get_tree().get_nodes_in_group(g):
			var v: Vector2 = (n as Node2D).global_position - global_position
			v.y *= 2.0
			if v.length() < flee_distance:
				return n
	return null


func _take_off(from) -> void:
	var away := Vector2.from_angle(randf() * TAU)
	if from:
		away = (global_position - (from as Node2D).global_position).normalized()
	var p := global_position + away * randf_range(120.0, 220.0) * Vector2(1.0, 0.5)
	# stay around home
	if p.distance_to(home) > home_radius * 1.4:
		p = home + (p - home).limit_length(home_radius)
	target = _ground_point(p, 0.0)
	_from = global_position
	_fly_total = global_position.distance_to(target)
	state = S.FLY
	sprite.rotation = 0.0
	sprite.play("fly")


## A point near p that is on dry land.
func _ground_point(p: Vector2, jitter: float) -> Vector2:
	var game := get_node_or_null("/root/Game")
	for i in 12:
		var q := p + Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * (jitter + i * 12.0)
		if q.distance_to(home) > home_radius:
			q = home + (q - home).limit_length(home_radius)
		if game == null or not game.has_method("is_water") or not game.is_water(q):
			return q
	return home
