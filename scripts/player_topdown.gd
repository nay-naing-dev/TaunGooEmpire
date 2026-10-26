extends CharacterBody2D
class_name IsoPlayer
## Isometric 8-directional action character for Godot 4.
##
## Scene setup:
##   Player (CharacterBody2D)  <- this script
##   ├── AnimatedSprite2D
##   └── CollisionShape2D
##
## Expected animation names in the SpriteFrames resource:
##   idle_<dir>, run_<dir>, attack_<dir>
##   where <dir> is one of: e, se, s, sw, w, nw, n, ne
##
## If the west-facing animations (w, sw, nw) are missing, the east-facing
## ones are mirrored with flip_h. If no directional version exists at all,
## a plain "idle" / "run" / "attack" animation is used as a fallback.

signal state_changed(previous: State, current: State)
signal health_changed(current: int, maximum: int)
signal died

enum State { IDLE, RUN, ATTACK }

## SCREEN_ALIGNED: W moves straight up the screen (Diablo / Hades style).
## GRID_ALIGNED:   W moves up-right along the isometric tile axis.
enum MoveMode { SCREEN_ALIGNED, GRID_ALIGNED }

@export_group("Movement")
@export var move_speed: float = 140.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
@export var movement_mode: MoveMode = MoveMode.SCREEN_ALIGNED
## Height/width ratio of your isometric tiles (0.5 for standard 2:1 iso).
@export_range(0.1, 1.0, 0.05) var iso_vertical_ratio: float = 0.5

@export_group("Combat")
@export var max_health: int = 100
@export var attack_damage: int = 12
## How far the attack reaches (ground pixels).
@export var attack_range: float = 64.0
## Seconds into the attack when the hit lands.
@export var hit_delay: float = 0.12

@export_group("Animation")
## Mirror east-facing animations for west directions when west ones are missing.
@export var mirror_west_animations: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Index order matches angle steps of 45° starting at east, going clockwise
## (Godot's y axis points down, so +45° is south-east).
const DIRECTIONS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var state: State = State.IDLE
var facing: int = 2  # Start facing south.
var input_vector: Vector2 = Vector2.ZERO
var health: int
var dead := false
var _invulnerable := 0.0
var _knockback := Vector2.ZERO


# --------------------------------------------------------------------------
# Lifecycle
# --------------------------------------------------------------------------

func _ready() -> void:
	health = max_health
	add_to_group("player")
	_ensure_input_actions()
	_disable_attack_loops()
	sprite.animation_finished.connect(_on_animation_finished)
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if dead:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	match state:
		State.IDLE:
			_state_idle(delta)
		State.RUN:
			_state_run(delta)
		State.ATTACK:
			_state_attack(delta)

	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	_update_animation()


# --------------------------------------------------------------------------
# State machine
# --------------------------------------------------------------------------

func _state_idle(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		return
	if input_vector != Vector2.ZERO:
		change_state(State.RUN)
		return

	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _state_run(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
		return
	if input_vector == Vector2.ZERO:
		change_state(State.IDLE)
		return

	var iso_direction := to_isometric(input_vector)
	velocity = velocity.move_toward(iso_direction * move_speed * (0.65 if Game.is_water(global_position) else 1.0), acceleration * delta)  # slower when wading
	_update_facing(iso_direction)


func _state_attack(_delta: float) -> void:
	# Movement is fully locked until the attack animation finishes.
	velocity = Vector2.ZERO


func change_state(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	_exit_state(previous)
	state = new_state
	_enter_state(new_state)
	state_changed.emit(previous, new_state)


func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			pass
		State.RUN:
			pass
		State.ATTACK:
			velocity = Vector2.ZERO
			# Let the player aim the attack with whatever direction is held.
			if input_vector != Vector2.ZERO:
				_update_facing(to_isometric(input_vector))
			# Always restart the attack from frame 0.
			_play_directional("attack", true)
			get_tree().create_timer(hit_delay).timeout.connect(_deal_damage)


func _exit_state(_old_state: State) -> void:
	pass


func _on_animation_finished() -> void:
	if state == State.ATTACK:
		change_state(State.IDLE)


# --------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------

## Hits every node in the "enemy" group that is in front of us and close enough.
func _deal_damage() -> void:
	if dead or state != State.ATTACK:
		return
	var aim := Vector2.from_angle(facing * TAU / 8.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector2 = from_isometric((e as Node2D).global_position - global_position)
		var dist := to.length()
		if dist <= attack_range and (dist < 14.0 or aim.dot(to / dist) > 0.25):
			if e.has_method("take_hit"):
				e.take_hit(attack_damage, global_position)


## Called by enemies.
func take_hit(amount: int, from_position: Vector2) -> void:
	if dead or _invulnerable > 0.0:
		return
	health = max(health - amount, 0)
	_invulnerable = 0.6
	health_changed.emit(health, max_health)
	var away := (global_position - from_position)
	_knockback = (away.normalized() if away.length() > 0.1 else Vector2.DOWN) * 150.0
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.5), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if health == 0:
		dead = true
		velocity = Vector2.ZERO
		sprite.stop()
		var fade := create_tween()
		fade.tween_property(sprite, "modulate", Color(0.4, 0.2, 0.2, 0.0), 1.2)
		died.emit()


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


# --------------------------------------------------------------------------
# Isometric math
# --------------------------------------------------------------------------

## Converts a normalized WASD input vector into isometric screen space.
## The result keeps a consistent speed in "world" terms: moving in a circle
## on the ground traces an ellipse on screen, as it should in isometric view.
func to_isometric(input: Vector2) -> Vector2:
	var world := input
	if movement_mode == MoveMode.GRID_ALIGNED:
		# Rotate 45° so W/A/S/D follow the diamond tile edges.
		world = input.rotated(PI / 4.0)
	# Squash the vertical axis to match the tile projection.
	return Vector2(world.x, world.y * iso_vertical_ratio)


## Undoes the vertical squash so facing is computed from the true ground angle.
func from_isometric(screen: Vector2) -> Vector2:
	return Vector2(screen.x, screen.y / iso_vertical_ratio)


func _update_facing(iso_direction: Vector2) -> void:
	if iso_direction == Vector2.ZERO:
		return
	var ground_angle := from_isometric(iso_direction).angle()
	facing = wrapi(roundi(ground_angle / (TAU / 8.0)), 0, 8)


# --------------------------------------------------------------------------
# Animation
# --------------------------------------------------------------------------

func _update_animation() -> void:
	match state:
		State.IDLE:
			_play_directional("idle")
		State.RUN:
			_play_directional("run")
		State.ATTACK:
			pass  # Started once in _enter_state; never interrupted.


func _play_directional(base: String, restart: bool = false) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return

	var dir := DIRECTIONS[facing]
	var anim_name := "%s_%s" % [base, dir]
	var flip := false

	if not frames.has_animation(anim_name):
		var mirrored_name := "%s_%s" % [base, dir.replace("w", "e")]
		if mirror_west_animations and dir.contains("w") and frames.has_animation(mirrored_name):
			anim_name = mirrored_name
			flip = true
		elif frames.has_animation(base):
			anim_name = base
			# Non-directional fallback: still face left/right.
			flip = dir.contains("w")
		else:
			push_warning("IsoPlayer: missing animation '%s'" % anim_name)
			return

	sprite.flip_h = flip
	if restart:
		sprite.stop()
		sprite.play(anim_name)
	elif sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


## Attack animations must not loop, otherwise animation_finished never fires
## and the character would be stuck in ATTACK.
func _disable_attack_loops() -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	for anim_name in frames.get_animation_names():
		if anim_name.begins_with("attack"):
			frames.set_animation_loop(anim_name, false)


# --------------------------------------------------------------------------
# Input setup
# --------------------------------------------------------------------------

## Registers WASD (+ arrow keys) and J if the actions aren't already defined
## in Project Settings > Input Map. Existing mappings are left untouched.
func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("attack", [KEY_J])


func _add_key_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
