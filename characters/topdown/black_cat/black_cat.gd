extends CharacterBody2D
## Playable black cat, 8 directions.
##   WASD / arrows : walk
##   hold Shift    : run
##   C             : sit down / stand up  (it also sits by itself after a few idle seconds)
##   J             : pounce - leaps forward and swipes whatever it lands on
##   E             : talk to whoever is in reach (Game.interact)
## Same player API as the other characters (group "player", health, take_hit,
## health_changed, died), so the HUD, boss, grass, water and lighting all work.

signal health_changed(current: int, maximum: int)
signal died

@export_group("Movement")
@export var walk_speed: float = 40.0
@export var run_speed: float = 112.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
@export var iso_vertical_ratio: float = 0.5
## Seconds standing still before the cat sits down by itself (0 = never).
@export var auto_sit_after: float = 4.0

@export_group("Combat")
@export var max_health: int = 70
@export var pounce_damage: int = 16
@export var pounce_distance: float = 46.0
@export var pounce_range: float = 30.0

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
enum Mode { MOVE, SITTING_DOWN, SIT, STANDING_UP, POUNCE }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var eyes: AnimatedSprite2D = $Eyes

var health: int
var dead := false
var mode := Mode.MOVE
var facing := 0
var _still := 0.0
var _aim := Vector2.RIGHT
var _hit_done := false
var _invulnerable := 0.0
var _knockback := Vector2.ZERO


func _ready() -> void:
	health = max_health
	add_to_group("player")
	_ensure_input_actions()
	sprite.animation_finished.connect(_on_anim_done)
	sprite.frame_changed.connect(_on_frame)
	sprite.play("idle_e")


func _side() -> String:
	return "l" if DIRS[facing] in ["w", "nw", "sw"] else "r"


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if dead:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	var talking := _in_dialogue()  # stand still; E turns the dialogue's pages
	var input := Vector2.ZERO if talking else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wade := 0.65 if _in_water() else 1.0
	match mode:
		Mode.MOVE:
			if talking or (Input.is_action_just_pressed("interact") and _interact()):
				_move(Vector2.ZERO, wade, delta)
			elif Input.is_action_just_pressed("attack"):
				_start_pounce(input)
			elif Input.is_action_just_pressed("sit") and input == Vector2.ZERO:
				_sit()
			else:
				_move(input, wade, delta)
		Mode.SIT:
			velocity = Vector2.ZERO
			if input != Vector2.ZERO or (not talking and (Input.is_action_just_pressed("sit") or Input.is_action_just_pressed("attack"))):
				mode = Mode.STANDING_UP
				sprite.play("stand_up_" + _side())
		Mode.SITTING_DOWN, Mode.STANDING_UP:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		Mode.POUNCE:
			var airborne := sprite.frame >= 1 and sprite.frame <= 3
			var air_time := 3.0 / sprite.sprite_frames.get_animation_speed(sprite.animation)
			velocity = _aim * (pounce_distance / air_time if airborne else 0.0) * wade
	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)


func _move(input: Vector2, wade: float, delta: float) -> void:
	var running := Input.is_action_pressed("run")
	var target := Vector2(input.x, input.y * iso_vertical_ratio) * (run_speed if running else walk_speed) * wade
	velocity = velocity.move_toward(target, (acceleration if input != Vector2.ZERO else friction) * delta)
	if input != Vector2.ZERO:
		facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
		_still = 0.0
		var anim: String = ("run_" if running else "walk_") + DIRS[facing]
		if sprite.animation != anim:
			var ph := 0.0
			if sprite.animation.begins_with("walk") or sprite.animation.begins_with("run"):
				ph = float(sprite.frame) / sprite.sprite_frames.get_frame_count(sprite.animation)
			sprite.play(anim)
			sprite.frame = int(ph * sprite.sprite_frames.get_frame_count(anim))
		var ground := Vector2(velocity.x, velocity.y / iso_vertical_ratio).length()
		sprite.speed_scale = clampf(ground / ((run_speed if running else walk_speed) * maxf(wade, 0.01)), 0.4, 1.2)
	else:
		sprite.speed_scale = 1.0
		if sprite.animation != "idle_" + DIRS[facing]:
			sprite.play("idle_" + DIRS[facing])
		_still += delta
		if auto_sit_after > 0.0 and _still >= auto_sit_after:
			_sit()


func _sit() -> void:
	_still = 0.0
	mode = Mode.SITTING_DOWN
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0
	sprite.play("sit_down_" + _side())


func _start_pounce(input: Vector2) -> void:
	mode = Mode.POUNCE
	_hit_done = false
	if input != Vector2.ZERO:
		facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
	var dir := Vector2.from_angle(facing * TAU / 8.0)
	_aim = Vector2(dir.x, dir.y * iso_vertical_ratio).normalized()
	sprite.speed_scale = 1.0
	sprite.play("pounce_" + _side())


func _on_frame() -> void:
	if mode == Mode.POUNCE and not _hit_done and sprite.frame == 3:
		_hit_done = true
		var paws := global_position + _aim * 14.0
		for e in get_tree().get_nodes_in_group("enemy"):
			var to: Vector2 = (e as Node2D).global_position - paws
			to.y /= iso_vertical_ratio
			if to.length() <= pounce_range and e.has_method("take_hit"):
				e.take_hit(pounce_damage, global_position)


func _on_anim_done() -> void:
	match mode:
		Mode.SITTING_DOWN:
			mode = Mode.SIT
			sprite.play("sit")
		Mode.STANDING_UP, Mode.POUNCE:
			mode = Mode.MOVE
			sprite.play("idle_" + DIRS[facing])


func _process(_delta: float) -> void:
	# glowing eyes follow the body animation
	if eyes.animation != sprite.animation:
		eyes.animation = sprite.animation
	eyes.frame = sprite.frame
	eyes.modulate.a = sprite.modulate.a
	eyes.visible = sprite.visible


## Called by enemies.
func take_hit(amount: int, from_position: Vector2) -> void:
	if dead or _invulnerable > 0.0:
		return
	health = max(health - amount, 0)
	_invulnerable = 0.6
	health_changed.emit(health, max_health)
	if mode == Mode.SIT or mode == Mode.SITTING_DOWN:
		mode = Mode.MOVE
	var away := global_position - from_position
	_knockback = (away.normalized() if away.length() > 0.1 else Vector2.DOWN) * 160.0
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
	_add("attack", [KEY_J])
	_add("run", [KEY_SHIFT])
	_add("sit", [KEY_C])
	_add("interact", [KEY_E])


func _add(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
