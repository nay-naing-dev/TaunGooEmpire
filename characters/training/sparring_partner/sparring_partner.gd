extends CharacterBody2D
## Training-ground sparring partner (tutorial bot).
## A senior soldier in the indigo practice uniform. He fights with the same moves
## as the MC warrior (run, slash, parry, counter, lightning dodge) but is built to TEACH:
## every attack is telegraphed, he never kills the MC and he yields when beaten.
##
## lesson:
##   TUTORIAL  - runs the lessons below in order, with hint text over his head
##   STRIKE    - stands in guard and takes your hits. Goal: land full 3-hit combos.
##   PARRY     - slow attacks, a white flash before each blow. Goal: perfect parries.
##   DODGE     - RED flash = unblockable heavy blow (parry won't stop it). Goal: dodge them.
##   SPAR      - free sparring: he attacks, blocks, dodges and counters. Ends when he yields.
##   IDLE      - just stands and smokes (use it before / after story scenes)
##
## Story scripts:  say("text"), start_lesson(Lesson.PARRY), signals below.

signal lesson_progress(lesson: int, count: int, goal: int)
signal lesson_complete(lesson: int)
signal tutorial_complete
signal yielded

enum Lesson { TUTORIAL, STRIKE, PARRY, DODGE, SPAR, IDLE }
@export var lesson: Lesson = Lesson.TUTORIAL
@export var show_hints := true
@export var goal_strike := 2          ## full combos to land
@export var goal_parry := 3           ## perfect parries
@export var goal_dodge := 3           ## unblockables dodged
@export var max_health := 120
@export var spar_health := 220         ## toughness during the free sparring bout
@export var damage := 6               ## practice blade: small hits
@export var run_speed := 95.0
@export var keep_distance := 34.0
@export var attack_range := 40.0
@export var telegraph_time := 0.55    ## wind-up flash before each blow (longer = easier)
@export_range(0.0, 1.0) var block_chance := 0.35   ## SPAR: chance to parry your hit
@export_range(0.0, 1.0) var dodge_chance := 0.2    ## SPAR: chance to dodge your hit

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
enum { GUARD, APPROACH, TELEGRAPH, ATTACK, BLOCK, DODGE, STUN, YIELD, REST }
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sparks: CPUParticles2D = $Sparks
@onready var hint: Label = $Hint
@onready var mark: Label = $Mark

var state := REST
var facing := 2
var health := 0
var dead := false
var _t := 0.0
var _timer := 0.0
var _cool := 1.0
var _unblockable := false
var _hit_done := false
var _count := 0
var _tut_step := 0
var _player: Node2D
var _base := Vector2.ZERO
var _dodge_dir := Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("actor")
	add_to_group("training_bot")
	health = max_health
	_base = sprite.offset
	sprite.animation_finished.connect(_on_anim_done)
	sprite.frame_changed.connect(_on_frame)
	mark.visible = false
	hint.visible = false
	_hook_player.call_deferred()
	start_lesson(lesson)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player and _player.has_signal("perfect_parry") and not _player.perfect_parry.is_connected(_on_player_parry):
		_player.perfect_parry.connect(_on_player_parry)


# ------------------------------------------------------------------ lessons
func start_lesson(l: Lesson, _from_tutorial := false) -> void:
	if not _from_tutorial and has_meta("in_tutorial"):
		remove_meta("in_tutorial")
	lesson = l
	_count = 0
	health = max_health
	_cool = 1.2
	match l:
		Lesson.TUTORIAL:
			_tut_step = 0
			_next_tutorial_step()
			return
		Lesson.STRIKE:
			say("Strike me! Press ATTACK three times quickly for a full combo.")
		Lesson.PARRY:
			say("When I flash WHITE, press PARRY just before my blade lands.")
		Lesson.DODGE:
			say("A RED flash can't be parried. DODGE out of the way!")
		Lesson.SPAR:
			health = spar_health
			say("Now spar with me. Use everything you learned!")
		Lesson.IDLE:
			say("")
			state = REST
			return
	state = GUARD


func _next_tutorial_step() -> void:
	var order := [Lesson.STRIKE, Lesson.PARRY, Lesson.DODGE, Lesson.SPAR]
	if _tut_step >= order.size():
		say("Training complete. You are ready, soldier.")
		health = max_health
		remove_meta("in_tutorial")
		lesson = Lesson.IDLE
		state = REST
		tutorial_complete.emit()
		return
	var l: Lesson = order[_tut_step]
	_tut_step += 1
	set_meta("in_tutorial", true)
	start_lesson(l, true)


func _goal() -> int:
	match lesson:
		Lesson.STRIKE: return goal_strike
		Lesson.PARRY: return goal_parry
		Lesson.DODGE: return goal_dodge
	return 0


func _progress(msg: String) -> void:
	if _goal() == 0 or _count >= _goal():
		return
	_count += 1
	lesson_progress.emit(lesson, _count, _goal())
	if _count >= _goal():
		lesson_complete.emit(lesson)
		say("Good! " + msg)
		_cool = 2.5
		state = REST
		if has_meta("in_tutorial"):
			await get_tree().create_timer(2.2).timeout
			_next_tutorial_step()
	else:
		say("%s  (%d / %d)" % [msg, _count, _goal()])


## Speech / hint text above his head ("" hides it).
func say(text: String, secs := 0.0) -> void:
	hint.text = text
	hint.visible = show_hints and text != ""
	if secs > 0.0:
		await get_tree().create_timer(secs).timeout
		if hint.text == text:
			hint.visible = false


# ------------------------------------------------------------------ AI
func _dir() -> String:
	return DIRS[facing]


func _face(v: Vector2) -> void:
	if v.length() > 0.01:
		facing = wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)


func _fv() -> Vector2:
	return Vector2.RIGHT.rotated(facing * TAU / 8.0)


func _guard_pose() -> void:
	# guard stance = first frame of the parry, held
	var a := "parry_" + _dir()
	if sprite.animation != a or sprite.is_playing():
		sprite.play(a)
		sprite.pause()
		sprite.frame = 0


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	var p := _player
	var to_p := (p.global_position - global_position) if p else Vector2.ZERO
	var iso := Vector2(to_p.x, to_p.y * 2.0).length()
	match state:
		REST:
			velocity = Vector2.ZERO
			if p and iso < 120.0:
				_face(to_p)
			_play_loop("idle_" + _dir())      # smokes his cheroot
		GUARD, APPROACH:
			if p == null:
				return
			_face(to_p)
			var wants_attack := lesson in [Lesson.PARRY, Lesson.DODGE, Lesson.SPAR]
			if wants_attack and _cool <= 0.0 and iso < attack_range + 6.0:
				_begin_telegraph()
			elif lesson != Lesson.STRIKE and iso > (attack_range - 4.0 if wants_attack else keep_distance + 14.0):
				state = APPROACH
				velocity = to_p.normalized() * run_speed * Vector2(1, 0.6)
				_play_loop("run_" + _dir())
			elif iso < keep_distance - 12.0 and lesson != Lesson.STRIKE:
				velocity = -to_p.normalized() * run_speed * 0.4 * Vector2(1, 0.6)   # step back
				_guard_pose()
			else:
				state = GUARD
				velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
				_guard_pose()
				sprite.offset = _base + Vector2(0, -(0.5 + 0.5 * sin(_t * 3.0)) * 1.0)
			move_and_slide()
		TELEGRAPH:
			velocity = Vector2.ZERO
			_timer -= delta
			# flashing wind-up: white = parry it, red = dodge it
			var k := 0.5 + 0.5 * sin(_t * 30.0)
			var c := Color(2.2, 0.6, 0.5) if _unblockable else Color(1.9, 1.9, 1.7)
			sprite.modulate = Color.WHITE.lerp(c, k)
			if _timer <= 0.0:
				sprite.modulate = Color.WHITE
				mark.visible = false
				state = ATTACK
				_hit_done = false
				sprite.play("attack_" + _dir())
				sprite.frame = 1
				sprite.speed_scale = 0.6 if lesson == Lesson.PARRY else 1.0
				var f := _fv()
				velocity = Vector2(f.x, f.y * 0.5) * 80.0
		ATTACK, BLOCK:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()
		DODGE:
			_timer -= delta
			velocity = Vector2(_dodge_dir.x, _dodge_dir.y * 0.5) * (380.0 if _timer > 0.08 else 60.0)
			move_and_slide()
			if _timer <= 0.0:
				sprite.modulate = Color.WHITE
				state = GUARD
				_cool = 0.4
		STUN:
			_timer -= delta
			sprite.offset = _base + Vector2(sin(_t * 9.0) * 1.5, 0)
			sprite.rotation = sin(_t * 4.5) * 0.05
			if _timer <= 0.0:
				sprite.rotation = 0.0
				sprite.offset = _base
				sprite.modulate = Color.WHITE
				state = GUARD
				_cool = 0.8
		YIELD:
			velocity = Vector2.ZERO


func _play_loop(a: String) -> void:
	sprite.speed_scale = 1.0
	sprite.offset = _base
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)


func _begin_telegraph() -> void:
	state = TELEGRAPH
	_unblockable = lesson == Lesson.DODGE or (lesson == Lesson.SPAR and randf() < 0.25)
	_timer = telegraph_time * (1.4 if lesson in [Lesson.PARRY, Lesson.DODGE] else 1.0)
	sprite.play("attack_" + _dir())
	sprite.pause()
	sprite.frame = 0
	mark.text = "!!" if _unblockable else "!"
	mark.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if _unblockable else Color(1, 1, 0.8))
	mark.visible = true


func _on_frame() -> void:
	if state != ATTACK or _hit_done or sprite.frame < 2:
		return
	_hit_done = true
	var p := _player
	if p == null or not p.has_method("take_hit"):
		return
	var v := p.global_position - global_position
	var in_reach := Vector2(v.x, v.y * 2.0).length() < attack_range + 10.0
	var p_state = p.get("state")
	var dodging: bool = p_state == 3                       # mc_warrior DODGE
	if lesson == Lesson.DODGE and _unblockable:
		if dodging or not in_reach:
			_progress("Nice dodge!")
			return
	if not in_reach or dodging:
		return
	if _unblockable and p.get("_parry_t") != null:
		p.set("_parry_t", 99.0)                      # parry can't stop a heavy blow
		say("Can't parry that one - dodge it!", 2.0)
	var hp = p.get("health")
	if hp != null and hp <= damage * 2 and p.has_method("heal_full"):
		p.heal_full()                                # practice bout: never knocks the MC out
		say("Catch your breath... again!", 2.0)
	p.take_hit(damage, global_position)
	_spark(v.normalized(), 10)


func _on_anim_done() -> void:
	if state == ATTACK:
		state = GUARD
		_cool = randf_range(1.0, 1.6) if lesson != Lesson.SPAR else randf_range(0.5, 1.1)
		sprite.speed_scale = 1.0
	elif state == BLOCK:
		state = GUARD
		if lesson == Lesson.SPAR and randf() < 0.5 and _player:
			_cool = 0.0                              # block -> instant riposte
	elif state == YIELD:
		pass


func _on_player_parry(enemy: Node) -> void:
	if enemy != self:
		return
	if lesson == Lesson.PARRY:
		_progress("Perfect parry!")


# ------------------------------------------------------------------ being hit
func stun(secs: float) -> void:
	if state == YIELD:
		return
	state = STUN
	_timer = secs
	mark.visible = false
	sprite.modulate = Color(0.85, 0.85, 1.0)
	_guard_pose()


func is_stunned() -> bool:
	return state == STUN


func take_hit(amount: int, from_position: Vector2) -> void:
	if state == YIELD or state == DODGE:
		return
	var v := from_position - global_position
	# in free sparring he sometimes blocks or slips away (teaches: don't just mash attack)
	if lesson == Lesson.SPAR and state in [GUARD, APPROACH]:
		var r := randf()
		if r < dodge_chance:
			_do_dodge(-v)
			return
		if r < dodge_chance + block_chance:
			_do_block(v)
			return
	health -= amount
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.7, 0.7), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE if state != STUN else Color(0.85, 0.85, 1.0), 0.2)
	if v.length() > 0.1:
		var kt := create_tween()
		kt.tween_property(self, "global_position", global_position - v.normalized() * Vector2(1, 0.5) * 6.0, 0.08)
	if lesson == Lesson.STRIKE:
		health = max_health                          # practice: never runs out
		if _player and _player.get("_combo") == 2:
			_progress("Full combo!")
	if lesson != Lesson.SPAR:
		health = maxi(health, max_health / 2)        # only free sparring can beat him
	elif health <= spar_health * 0.15:
		_yield()


func _do_block(v: Vector2) -> void:
	_face(v)
	state = BLOCK
	sprite.play("parry_" + _dir())
	sprite.frame = 0
	_spark(v.normalized(), 22)
	say("Blocked! Mix up your attacks.", 1.5)


func _do_dodge(away: Vector2) -> void:
	state = DODGE
	_dodge_dir = away.normalized() if away.length() > 0.1 else -_fv()
	_timer = 0.22
	sprite.play("dodge_" + _dir())
	sprite.frame = 1
	sprite.modulate = Color(1.6, 1.6, 2.0, 0.6)


func _yield() -> void:
	state = YIELD
	health = max(health, 1)
	mark.visible = false
	sprite.modulate = Color.WHITE
	sprite.play("dodge_" + _dir())
	sprite.frame = 3                                 # drops to one knee
	sprite.pause()
	say("Enough! Well fought, soldier.")
	yielded.emit()
	if has_meta("in_tutorial") and lesson == Lesson.SPAR:
		await get_tree().create_timer(2.5).timeout
		_next_tutorial_step()


func _spark(dir: Vector2, amount: int) -> void:
	sparks.position = Vector2(dir.x * 14.0, dir.y * 7.0 - 30.0)
	sparks.amount = amount
	sparks.restart()
	sparks.emitting = true
