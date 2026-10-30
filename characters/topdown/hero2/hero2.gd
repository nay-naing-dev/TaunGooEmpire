extends CharacterBody2D
## Main character (village boy). 8 directions, walk / run / idle.
##   WASD / arrows : walk
##   hold Shift    : run
##   E             : talk to whoever is in reach (Game.interact), else wave hello
## Same player API as the other characters (group "player", health, take_hit,
## health_changed, died), so the HUD, boss, grass, water and lighting all work.

signal health_changed(current: int, maximum: int)
signal died

@export var walk_speed: float = 62.0
@export var run_speed: float = 130.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
## Up/down movement is squashed to match the ground perspective.
@export var iso_vertical_ratio: float = 0.5
@export var max_health: int = 100
## Directions without run frames play the walk this much faster when running.
@export var run_walk_rate: float = 1.6

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: CPUParticles2D = $Dust

var health: int
var dead := false
var facing := 2               # index in DIRS, starts facing the camera
var waving := false
var _invulnerable := 0.0
var _knockback := Vector2.ZERO


func _ready() -> void:
	health = max_health
	add_to_group("player")
	_ensure_input_actions()
	sprite.animation_finished.connect(func():
		if sprite.animation == "wave":
			waving = false)
	sprite.play("idle_s")


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if dead:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	var talking := _in_dialogue()  # stand still; E turns the dialogue's pages
	var input := Vector2.ZERO if talking else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var talked := talking or (Input.is_action_just_pressed("interact") and _interact())
	if not talked and Input.is_action_just_pressed("wave") and not waving and sprite.sprite_frames.has_animation("wave"):
		waving = true
		velocity = Vector2.ZERO
		sprite.play("wave")
		sprite.frame = 0
	if waving and input != Vector2.ZERO:
		waving = false
	var running := Input.is_action_pressed("run")
	var wade := 0.65 if _in_water() else 1.0
	if waving:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var target := Vector2(input.x, input.y * iso_vertical_ratio) * (run_speed if running else walk_speed) * wade
		velocity = velocity.move_toward(target, (acceleration if input != Vector2.ZERO else friction) * delta)
		if input != Vector2.ZERO:
			facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
		var base := "idle"
		if input != Vector2.ZERO:
			base = "run" if running else "walk"
		var anim: String = "%s_%s" % [base, DIRS[facing]]
		var fast := 1.0
		if not sprite.sprite_frames.has_animation(anim):
			anim = "walk_%s" % DIRS[facing]       # no run frames for this direction: fast walk
			fast = run_walk_rate
		if sprite.animation != anim:
			# keep the step phase when turning (frame counts differ per direction)
			var ph := 0.0
			if base != "idle" and not sprite.animation.begins_with("idle") and sprite.animation != "wave":
				ph = float(sprite.frame) / maxf(sprite.sprite_frames.get_frame_count(sprite.animation), 1.0)
			sprite.play(anim)
			sprite.frame = int(ph * sprite.sprite_frames.get_frame_count(anim))
		# speed the walk animation to the actual ground speed (no foot sliding)
		if base != "idle":
			# ground speed (undo the up/down squash) so walking up/down animates as fast as sideways
			var ground := Vector2(velocity.x, velocity.y / iso_vertical_ratio).length()
			var full := run_speed if running else walk_speed
			sprite.speed_scale = clampf(ground / (full * maxf(wade, 0.01)), 0.4, 1.2) * fast
		else:
			sprite.speed_scale = 1.0
	dust.emitting = running and input != Vector2.ZERO and not _in_water()
	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)


## Called by enemies.
func take_hit(amount: int, from_position: Vector2) -> void:
	if dead or _invulnerable > 0.0:
		return
	health = max(health - amount, 0)
	_invulnerable = 0.6
	health_changed.emit(health, max_health)
	var away := global_position - from_position
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


## Gives back amount health (up to max_health), e.g. from eating.
func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _in_water() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.has_method("is_water") and game.is_water(global_position)


func _interact() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.has_method("interact") and game.interact(self)


func _in_dialogue() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.has_method("in_dialogue") and game.in_dialogue()


func _ensure_input_actions() -> void:
	_add("move_up", [KEY_W, KEY_UP])
	_add("move_down", [KEY_S, KEY_DOWN])
	_add("move_left", [KEY_A, KEY_LEFT])
	_add("move_right", [KEY_D, KEY_RIGHT])
	_add("run", [KEY_SHIFT])
	_add("wave", [KEY_E])
	_add("interact", [KEY_E])


func _add(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
