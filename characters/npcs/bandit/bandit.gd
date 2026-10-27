extends CharacterBody2D
## Forest bandit (two builds share this script: "brute" and "raider").
## - variant: clothing colour (0 red, 1 indigo, 2 mustard, 3 green, -1 = random).
## - Waits at its ambush spot breathing, turns to watch the MC when he comes near.
## - aggressive = true: charges the MC, slashes when close, gives up and walks
##   back when he gets far away.  (Story scripts can call ambush() / calm_down().)
## - take_hit() / die(): raider has a fall-down animation, brute topples over.

signal died

@export var frames_base := "res://characters/npcs/bandit/bandit_raider"
@export_range(-1, 3) var variant := -1
@export var start_facing := "s"
@export var aggressive := false
@export var notice_radius := 170.0
@export var chase_radius := 340.0
@export var attack_range := 22.0
@export var run_speed := 88.0
@export var damage := 8
@export var max_health := 30
@export var hit_frame := 1          # attack frame that lands the blow

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
enum { WAIT, CHASE, ATTACK, RETURN, DEAD }
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var state := WAIT
var facing := "s"
var health := 0
var home := Vector2.ZERO
var _t := 0.0
var _cool := 0.0
var _hit_done := false
var _base := Vector2.ZERO


func _ready() -> void:
	add_to_group("actor")
	add_to_group("bandit")
	health = max_health
	home = global_position
	facing = start_facing
	var v := variant if variant >= 0 else randi() % 4
	var path := "%s_v%d.tres" % [frames_base, v]
	if ResourceLoader.exists(path):
		sprite.sprite_frames = load(path)
	_base = sprite.offset
	_t = randf() * 10.0
	sprite.animation_finished.connect(_on_anim_done)
	sprite.frame_changed.connect(_on_frame)
	_play("idle")


func ambush() -> void:
	aggressive = true


func calm_down() -> void:
	aggressive = false
	if state != DEAD:
		state = RETURN


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _iso_len(v: Vector2) -> float:
	return Vector2(v.x, v.y * 2.0).length()


func _face(v: Vector2) -> void:
	if v.length() > 0.01:
		facing = DIRS[wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)]


func _play(kind: String) -> void:
	var a := "%s_%s" % [kind, facing]
	if not sprite.sprite_frames.has_animation(a):
		a = "idle_" + facing
	if sprite.animation != a or not sprite.is_playing():
		var keep := sprite.frame if kind == "run" and String(sprite.animation).begins_with("run") else 0
		sprite.play(a)
		sprite.frame = keep


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	if state == DEAD:
		return
	var p := _player()
	var to_p := (p.global_position - global_position) if p else Vector2.ZERO
	var p_alive: bool = p != null and not p.get("dead")
	match state:
		WAIT:
			velocity = Vector2.ZERO
			if p_alive and _iso_len(to_p) < notice_radius:
				_face(to_p)
				if aggressive:
					state = CHASE
			_play("idle")
			# slow breathing while waiting in the bushes
			sprite.offset = _base + Vector2(0, -(0.5 + 0.5 * sin(_t * 1.7)) * 0.9)
		CHASE:
			if not p_alive or _iso_len(to_p) > chase_radius or not aggressive:
				state = RETURN
			elif to_p.length() < attack_range and _cool <= 0.0:
				_face(to_p)
				state = ATTACK
				_hit_done = false
				_play("attack")
			else:
				_face(to_p)
				velocity = to_p.normalized() * run_speed * Vector2(1, 0.7)
				move_and_slide()
				_play("run")
			sprite.offset = _base
		ATTACK:
			velocity = Vector2.ZERO
		RETURN:
			var d := home - global_position
			if p_alive and aggressive and _iso_len(to_p) < notice_radius:
				state = CHASE
			elif d.length() < 3.0:
				state = WAIT
			else:
				_face(d)
				velocity = d.normalized() * run_speed * 0.45
				move_and_slide()
				_play("run")
				sprite.speed_scale = 0.55
				return
	sprite.speed_scale = 1.0


func _on_frame() -> void:
	if state != ATTACK or _hit_done or sprite.frame < hit_frame:
		return
	_hit_done = true
	var p := _player()
	if p and p.has_method("take_hit") and (p.global_position - global_position).length() < attack_range + 14.0:
		p.take_hit(damage, global_position)


func _on_anim_done() -> void:
	if state == ATTACK:
		_cool = randf_range(0.5, 1.0)
		state = CHASE
		_play("idle")


func take_hit(amount: int, from_position: Vector2) -> void:
	if state == DEAD:
		return
	health -= amount
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.6, 0.6), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if health <= 0:
		die(from_position)
	else:
		aggressive = true
		state = CHASE


func die(from_position := Vector2.ZERO) -> void:
	if state == DEAD:
		return
	state = DEAD
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	if from_position != Vector2.ZERO:
		_face(from_position - global_position)
	var a := "death_" + facing
	if sprite.sprite_frames.has_animation(a):
		sprite.play(a)
	else:
		# no fall animation (brute): topple over sideways and settle
		sprite.stop()
		var side := -1.0 if facing in ["w", "nw", "sw"] else 1.0
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "rotation", side * PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(sprite, "position", Vector2(side * 26.0, -6.0), 0.45)
		tw.tween_property(sprite, "modulate", Color(0.75, 0.7, 0.7), 0.8)
	z_index = -1
	died.emit()
