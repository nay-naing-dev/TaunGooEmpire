extends CharacterBody2D
## MC version 2: the warrior (test build, story unlock comes later).
##   WASD / arrows : move (hold Shift to run fast)
##   J / left mouse   : attack.  Press again during a swing for a 3-hit combo:
##                      slash -> quick return slash -> heavy finisher (lunges forward)
##                      Sparks fly off the blade on every swing, more on a hit.
##   Standing still he smokes his cheroot (idle).
##   K / right mouse  : parry.  If an enemy blade lands in the first moment of
##                      the parry it is a PERFECT PARRY: no damage, sparks,
##                      a short freeze and the attacker is STUNNED (takes double damage).
##                      A late parry still blocks half the damage.
##   Space            : lightning dodge: he crouches, vanishes in a flash of lightning,
##                      streaks a few metres and lands (invulnerable the whole time)
##   Perfect parry is followed by an automatic counter-lunge on the stunned enemy.
## Same player API as the other characters (group "player", health, take_hit,
## health_changed, died), so HUD, enemies, grass, water and lighting all work.

signal health_changed(current: int, maximum: int)
signal died
signal perfect_parry(enemy: Node)

@export var walk_speed := 70.0
@export var run_speed := 135.0
@export var acceleration := 1000.0
@export var friction := 1300.0
@export var iso_vertical_ratio := 0.5
@export var max_health := 120

@export_group("Combat")
@export var combo_damage: PackedInt32Array = PackedInt32Array([10, 12, 22])
@export var attack_range := 46.0
@export var combo_window := 0.35         ## seconds after a swing ends where the next press continues the combo
@export var parry_window := 0.2          ## perfect-parry time from the start of the parry
@export var parry_time := 0.42
@export var stun_time := 1.8
@export var dodge_speed := 520.0
@export var dodge_time := 0.16          ## time spent invisible, streaking
@export var dodge_cooldown := 0.35

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
enum { FREE, ATTACK, PARRY, DODGE, COUNTER }
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: CPUParticles2D = $Dust
@onready var sparks: CPUParticles2D = $ParrySparks

var health := 0
var dead := false
var facing := 2
var state := FREE
var _smoking := false            # F: light the cheroot (old smoking idle), any move/action stops it
var _f_down := false
var _combo := 0                 # 0..2 index of the current / last swing
var _queued := false
var _combo_timer := 0.0
var _hit_done := false
var _parry_t := 0.0
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _invulnerable := 0.0
var _knockback := Vector2.ZERO
var _t := 0.0
var _base_offset := Vector2.ZERO
var _still := 0.0
@onready var slash_sparks: CPUParticles2D = $SlashSparks


func _ready() -> void:
	health = max_health
	add_to_group("player")
	_ensure_input_actions()
	_base_offset = sprite.offset
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle_s")


func _dir() -> String:
	return DIRS[facing]


func _facing_vec() -> Vector2:
	return Vector2.RIGHT.rotated(facing * TAU / 8.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	if dead:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var f_now := Input.is_physical_key_pressed(KEY_F)
	if f_now and not _f_down and state == FREE:
		_smoking = not _smoking
	_f_down = f_now
	if state != FREE or input != Vector2.ZERO:
		_smoking = false
	match state:
		FREE:
			if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0:
				_start_dodge(input)
			elif Input.is_action_just_pressed("parry"):
				_start_parry()
			elif Input.is_action_just_pressed("attack"):
				_start_attack(_combo + 1 if _combo_timer > 0.0 and _combo < 2 else 0, input)
			else:
				_move(input, delta)
		ATTACK:
			if Input.is_action_just_pressed("attack"):
				_queued = true
			if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0:
				_start_dodge(input)          # dodge-cancel out of a swing
			velocity = velocity.move_toward(Vector2.ZERO, friction * 0.6 * delta)
		PARRY:
			_parry_t += delta
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if _parry_t >= parry_time and not sprite.is_playing():
				state = FREE
		DODGE:
			_dodge_t += delta
			if _dodge_t < WINDUP:
				velocity = Vector2.ZERO
			elif _dodge_t < WINDUP + dodge_time:
				if not _vanished:
					_vanish()
				velocity = Vector2(_dodge_dir.x, _dodge_dir.y * iso_vertical_ratio) * dodge_speed
			else:
				if _vanished:
					_reappear()
				velocity = velocity.move_toward(Vector2.ZERO, friction * 2.0 * delta)
				if not sprite.is_playing():
					state = FREE
		COUNTER:
			velocity = velocity.move_toward(Vector2.ZERO, friction * 0.8 * delta)
	dust.emitting = (state == DODGE) or (state == FREE and Input.is_action_pressed("run") and input != Vector2.ZERO)
	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)


func _move(input: Vector2, delta: float) -> void:
	var running := Input.is_action_pressed("run")
	var target := Vector2(input.x, input.y * iso_vertical_ratio) * (run_speed if running else walk_speed)
	velocity = velocity.move_toward(target, (acceleration if input != Vector2.ZERO else friction) * delta)
	if input != Vector2.ZERO:
		_still = 0.0
		facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
		_play("run_" + _dir(), true)
		var ground := Vector2(velocity.x, velocity.y / iso_vertical_ratio).length()
		sprite.speed_scale = clampf(ground / run_speed, 0.45, 1.15) * (1.0 if running else 0.8)
		sprite.offset = _base_offset
	else:
		_still += delta
		_play(("smoke_" if _smoking else "idle_") + _dir())
		sprite.speed_scale = 1.0
		sprite.offset = _base_offset


func _play(anim: String, keep_phase := false) -> void:
	if sprite.animation == anim and sprite.is_playing():
		return
	var ph := 0.0
	if keep_phase and String(sprite.animation).begins_with("run"):
		ph = float(sprite.frame) / maxf(sprite.sprite_frames.get_frame_count(sprite.animation), 1.0)
	sprite.play(anim)
	if keep_phase:
		sprite.frame = int(ph * sprite.sprite_frames.get_frame_count(anim))


# ------------------------------------------------------------------ attack combo
func _start_attack(step: int, input: Vector2) -> void:
	if input != Vector2.ZERO:
		facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
	else:
		_aim_at_nearest_enemy()
	state = ATTACK
	_combo = step
	_queued = false
	_hit_done = false
	sprite.offset = _base_offset
	_still = 0.0
	sprite.play("attack_" + _dir())
	# 1st: full swing, 2nd: quick return slash (starts mid-swing), 3rd: fast heavy finisher
	sprite.frame = 1 if step == 1 else 0
	sprite.speed_scale = [1.0, 1.25, 1.4][step]
	# step into the swing; the finisher lunges
	var f := _facing_vec()
	velocity = Vector2(f.x, f.y * iso_vertical_ratio) * (170.0 if step == 2 else 70.0)


func _aim_at_nearest_enemy() -> void:
	var best: Node2D = null
	var bd := 90.0
	for e in _enemies():
		var d := Vector2(e.global_position.x - global_position.x, (e.global_position.y - global_position.y) * 2.0).length()
		if d < bd:
			bd = d
			best = e
	if best:
		var v := best.global_position - global_position
		facing = wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)


func _enemies() -> Array:
	var out: Array = []
	for g in ["bandit", "enemy", "boss"]:
		for e in get_tree().get_nodes_in_group(g):
			if e != self and e is Node2D and e.has_method("take_hit") and not out.has(e):
				out.append(e)
	return out


func _on_frame_changed() -> void:
	if state == COUNTER and not _hit_done and sprite.frame >= 1:
		_hit_done = true
		var t := _counter_target
		if is_instance_valid(t) and t.global_position.distance_to(global_position) < attack_range + 30.0 and t.get("dead") != true:
			var dmg: int = combo_damage[2]
			if t.has_method("is_stunned") and t.is_stunned():
				dmg *= 2
			t.take_hit(dmg, global_position)
			_spark_burst(_facing_vec(), 36, 2.0)
			_hitstop(0.1)
			_shake(3.0)
		return
	if state != ATTACK or _hit_done:
		return
	if sprite.frame < 2:          # frame 2 is where the blade sweeps
		return
	_hit_done = true
	var f := _facing_vec()
	_spark_burst(f, 14 if _combo < 2 else 26, 1.0 if _combo < 2 else 1.5)
	var hit_any := false
	for e in _enemies():
		if e.get("state") != null and e.get("dead") == true:
			continue
		var v: Vector2 = e.global_position - global_position
		var iso := Vector2(v.x, v.y * 2.0)
		if iso.length() > attack_range + (10.0 if _combo == 2 else 0.0):
			continue
		if iso.length() > 10.0 and iso.normalized().dot(f) < 0.1:
			continue
		var dmg: int = combo_damage[clampi(_combo, 0, combo_damage.size() - 1)]
		if e.has_method("is_stunned") and e.is_stunned():
			dmg *= 2              # counter hit on a stunned enemy
		e.take_hit(dmg, global_position)
		hit_any = true
	if hit_any:
		_spark_burst(f, 30, 1.8)
		_hitstop(0.06 if _combo < 2 else 0.11)
		_shake(1.5 if _combo < 2 else 3.0)


func _on_anim_finished() -> void:
	if state == ATTACK:
		if _queued and _combo < 2:
			_start_attack(_combo + 1, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
			return
		state = FREE
		_combo_timer = combo_window if _combo < 2 else 0.0
		if _combo >= 2:
			_combo = -1          # next press starts again from the first slash
		sprite.speed_scale = 1.0
	elif state == PARRY or state == COUNTER:
		state = FREE
		sprite.speed_scale = 1.0


func _spark_burst(f: Vector2, amount: int, power: float) -> void:
	# blade tip: in front of the body at chest height
	slash_sparks.position = Vector2(f.x * 26.0, f.y * 13.0 - 30.0)
	slash_sparks.direction = Vector2(f.x, f.y * 0.5 - 0.35).normalized()
	slash_sparks.amount = amount
	slash_sparks.initial_velocity_min = 70.0 * power
	slash_sparks.initial_velocity_max = 170.0 * power
	slash_sparks.restart()
	slash_sparks.emitting = true


# ------------------------------------------------------------------ parry
func _start_parry() -> void:
	_still = 0.0
	_aim_at_nearest_enemy()
	state = PARRY
	_parry_t = 0.0
	sprite.offset = _base_offset
	sprite.play("parry_" + _dir())
	sprite.frame = 0
	sprite.speed_scale = 1.0


func _do_perfect_parry(from_position: Vector2) -> void:
	var attacker: Node2D = null
	var bd := 80.0
	for e in _enemies():
		var d: float = e.global_position.distance_to(from_position)
		if d < bd:
			bd = d
			attacker = e
	sparks.position = Vector2(0, -36) + (from_position - global_position).normalized() * 10.0
	sparks.restart()
	sparks.emitting = true
	_spark_burst((from_position - global_position).normalized(), 34, 1.6)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(2.2, 1.9, 1.2), 0.04)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	_hitstop(0.14)
	_shake(3.5)
	_invulnerable = 0.4
	if attacker:
		if attacker.has_method("stun"):
			attacker.stun(stun_time)
		var away: Vector2 = (attacker.global_position - global_position).normalized()
		if attacker is CharacterBody2D:
			var a := attacker as CharacterBody2D
			var t2 := a.create_tween()
			t2.tween_property(a, "global_position", a.global_position + away * 12.0, 0.12)
	perfect_parry.emit(attacker)
	_parry_t = parry_window      # one perfect parry per press
	if attacker:
		await get_tree().create_timer(0.2, true, false, true).timeout
		if not dead and (state == PARRY or state == FREE) and is_instance_valid(attacker):
			_start_counter(attacker)


var _counter_target: Node2D


func _start_counter(target: Node2D) -> void:
	state = COUNTER
	_counter_target = target
	var v := target.global_position - global_position
	facing = wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)
	sprite.play("counter_" + _dir())
	sprite.frame = 0
	sprite.speed_scale = 1.0
	var f := _facing_vec()
	velocity = Vector2(f.x, f.y * iso_vertical_ratio) * 230.0      # lunge in
	_hit_done = false


# ------------------------------------------------------------------ dodge
const WINDUP := 0.07
var _vanished := false
var _dodge_from := Vector2.ZERO


func _start_dodge(input: Vector2) -> void:
	_dodge_dir = input.normalized() if input != Vector2.ZERO else -_facing_vec()   # no input: blink backwards
	if input != Vector2.ZERO:
		facing = wrapi(roundi(input.angle() / (TAU / 8.0)), 0, 8)
	state = DODGE
	_dodge_t = 0.0
	_vanished = false
	_dodge_cd = dodge_cooldown + dodge_time
	_invulnerable = WINDUP + dodge_time + 0.12
	sprite.offset = _base_offset
	sprite.play("dodge_" + _dir())
	sprite.frame = 0
	sprite.pause()                     # crouch, then vanish


func _vanish() -> void:
	_vanished = true
	_dodge_from = global_position
	_ghost(Color(0.55, 0.8, 1.0, 0.8))
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.5, 1.0), 0.03)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.03)
	_flash_light(_dodge_from)


func _reappear() -> void:
	_vanished = false
	_lightning(_dodge_from, global_position)
	_flash_light(global_position)
	sprite.modulate = Color(2.6, 2.6, 3.2, 1.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.22)
	sprite.play("dodge_" + _dir())
	sprite.frame = 3                   # land on one knee and rise
	sprite.speed_scale = 1.4
	_shake(1.2)


## blue-white afterimage of the current frame, left where he vanished
func _ghost(tint: Color) -> void:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var g := Sprite2D.new()
	g.texture = tex
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.scale = sprite.scale
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.modulate = tint
	g.top_level = true
	g.global_position = global_position
	g.z_index = z_index
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.35)
	tw.tween_callback(g.queue_free)


## jagged lightning bolt from where he vanished to where he lands
func _lightning(a: Vector2, b: Vector2) -> void:
	var lift := Vector2(0, -26)
	for layer in 2:
		var l := Line2D.new()
		l.top_level = true
		l.z_index = 6
		l.width = 5.0 if layer == 0 else 1.6
		l.default_color = Color(0.45, 0.7, 1.0, 0.55) if layer == 0 else Color(1, 1, 1, 0.95)
		l.joint_mode = Line2D.LINE_JOINT_SHARP
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = m
		var n := 9
		var side := (b - a).orthogonal().normalized()
		for i in n + 1:
			var t := float(i) / n
			var j := 0.0 if i == 0 or i == n else randf_range(-9.0, 9.0)
			l.add_point(a.lerp(b, t) + lift + side * j + Vector2(0, randf_range(-6, 6)) * (0.0 if i == 0 or i == n else 1.0))
		get_parent().add_child(l)
		var tw := l.create_tween()
		tw.tween_interval(0.05)
		tw.tween_property(l, "modulate:a", 0.0, 0.25)
		tw.tween_callback(l.queue_free)


func _flash_light(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.global_position = at + Vector2(0, -26)
	p.z_index = 6
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.25
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.75, 0.9, 1.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ damage
## Called by enemies.
func take_hit(amount: int, from_position: Vector2) -> void:
	if dead:
		return
	if state == PARRY:
		if _parry_t < parry_window:
			_do_perfect_parry(from_position)
			return
		amount = int(ceil(amount * 0.5))       # late parry still blocks half
	if _invulnerable > 0.0 or state == DODGE or state == COUNTER:
		return
	health = max(health - amount, 0)
	_invulnerable = 0.5
	health_changed.emit(health, max_health)
	var away := global_position - from_position
	_knockback = (away.normalized() if away.length() > 0.1 else Vector2.DOWN) * 150.0
	if state == ATTACK:
		state = FREE                 # flinch out of the swing
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.5), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	_shake(2.0)
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


# ------------------------------------------------------------------ feel
func _hitstop(secs: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0


func _shake(amount: float) -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := create_tween()
	for i in 5:
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount, 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _ensure_input_actions() -> void:
	_add("move_up", [KEY_W, KEY_UP])
	_add("move_down", [KEY_S, KEY_DOWN])
	_add("move_left", [KEY_A, KEY_LEFT])
	_add("move_right", [KEY_D, KEY_RIGHT])
	_add("run", [KEY_SHIFT])
	_add("attack", [KEY_J], MOUSE_BUTTON_LEFT)
	_add("parry", [KEY_K], MOUSE_BUTTON_RIGHT)
	_add("dodge", [KEY_SPACE])


func _add(action: StringName, keys: Array, mouse := 0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	if mouse:
		var m := InputEventMouseButton.new()
		m.button_index = mouse
		InputMap.action_add_event(action, m)
