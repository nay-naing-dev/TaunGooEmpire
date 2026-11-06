extends "res://characters/palace/royal_npc.gd"
## The trainer on the palace training ground. Out of the story he is a palace
## character like the others (royal_npc.gd: demonstrates with idle_anim "train").
## - held = true: a story scene has him; he stands and breathes, the scene moves and
##   turns him (`facing`), or with watching = true he keeps his eyes on the player.
## - talk: set it and an "E" shows over him when the player is close; E calls it.
## - say(text): a line over his head. return_to(pos): walks back there and drills again.
## - start_spar() / stop_spar(): he fights the player (group "enemy" meanwhile):
##   steps in, raises his sword (a glint: the moment to parry) and cuts. His guard takes
##   half of every blow; only the first of a run makes him flinch (none while his
##   sword is up), he backs off after three, and now and then he turns one aside and
##   answers at once. A perfect parry stuns him (stun()): then blows land in full.
##   Never drops below 1 health and never takes the player below 1 either; the
##   story scene decides when it is over (health_changed).

signal health_changed(current: int, maximum: int)

@export var display_name := "Trainer"
@export var max_health := 200
@export var damage := 12
@export var spar_speed := 58.0
## Starts his cut from this close (ground distance, up / down counts double).
@export var attack_range := 40.0
## His sword hits up to this far.
@export var strike_reach := 50.0
@export var windup_time := 0.5
## Chance he turns a blow aside when it catches him standing ready.
@export_range(0.0, 1.0, 0.05) var block_chance := 0.3
## How much of a blow gets through his guard (all of it while a perfect parry has him reeling).
@export_range(0.0, 1.0, 0.05) var guard := 0.5

const SpeechBubble := preload("res://scripts/speech_bubble.gd")
enum { READY, WIND_UP, STRIKE, RECOVER, BACK_OFF, STAGGER, STUNNED }
## Frames of his "train" animation: open stance, drawing back, sword up, the cut, its follow-through, settling.
const OPEN := 0
const COIL := 1
const RAISED := 2
const CUT := 3
const FOLLOW := 4
const SETTLE := 5

var held := false
## While held: keeps turning to the player (watching a lesson).
var watching := false
var talk := Callable()
var health := 0
var dead := false
var sparring := false
var _state := READY
var _left := 0.0              # time left in the current state
var _cool := 1.0
var _hits_taken := 0
var _hits_clock := 0.0
var _away := Vector2.ZERO
var _bubble: SpeechBubble
var _post := Vector2.INF       # where return_to() is taking him
var _walk_t := 0.0
var _arena := Vector2.INF
var _arena_radius := 90.0


func _ready() -> void:
	super()
	health = max_health
	add_to_group("interactable")
	_bubble = SpeechBubble.new()
	_bubble.head_height = 82.0
	add_child(_bubble)


func say(text: String) -> void:
	_bubble.say(text)


func mark(text: String) -> void:
	_bubble.mark(text)


func _near(p: Node2D) -> bool:
	return p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < notice_radius


## Game.interact() asks these when the player presses E.
func can_interact(who: Node2D) -> bool:
	return talk.is_valid() and not held and not sparring and not Game.in_dialogue() and _near(who)


func interact(who: Node2D) -> void:
	_face(who.global_position - global_position)
	_play("idle")
	talk.call()


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_bubble.hint(p != null and can_interact(p))
	if sparring:
		_spar(delta, p)
	elif _post != Vector2.INF:
		_walk_back(delta)
	elif held or talk.is_valid():
		# standing for a story scene, or waiting to be talked to
		_t += delta
		if p and (watching or (talk.is_valid() and not held and _near(p))):
			_face(p.global_position - global_position)
		_play("idle")
		sprite.offset = _base + Vector2(0, -(0.5 + 0.5 * sin(_t * 1.7)) * breathe)
	else:
		super(delta)


## Out of a story scene: he walks back to pos by himself and goes on drilling there.
func return_to(pos: Vector2) -> void:
	held = false
	watching = false
	_post = pos
	_walk_t = 0.0


func _walk_back(delta: float) -> void:
	_t += delta
	_walk_t += delta
	var d := _post - global_position
	if d.length() < 2.0 or _walk_t > 15.0:  # 15 s: stuck on something, just arrive
		global_position = _post
		_post = Vector2.INF
		facing = start_facing
		return
	velocity = d.normalized() * spar_speed * 0.7 * Vector2(1.0, 0.75)
	move_and_slide()
	_face(d)
	_play("walk")
	sprite.offset = _base


# ------------------------------------------------------------------ spar
## arena: the middle of the sparring ground; when he backs off he stays within
## arena_radius of it (ground distance), so the fight doesn't drift behind buildings.
func start_spar(arena := Vector2.INF, arena_radius := 90.0) -> void:
	_arena = arena
	_arena_radius = arena_radius
	health = max_health
	health_changed.emit(health, max_health)
	sparring = true
	add_to_group("enemy")
	_state = READY
	_cool = 0.8
	_hits_taken = 0
	_pose(OPEN)


func stop_spar() -> void:
	sparring = false
	remove_from_group("enemy")
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.offset = _base
	_play("idle")


func is_stunned() -> bool:
	return sparring and _state == STUNNED


## A perfect parry: he reels, open to a counter, for secs.
func stun(secs: float) -> void:
	if not sparring:
		return
	_enter(STUNNED, secs)
	_pose(OPEN)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.7, 1.6, 1.2), 0.05)
	tw.tween_property(sprite, "modulate", Color(1.0, 0.9, 0.75), 0.3)


func take_hit(amount: int, from_position: Vector2) -> void:
	if not sparring:
		return
	if _state == READY and randf() < block_chance:
		_block(from_position)
		return
	if _state != STUNNED:
		amount = ceili(amount * guard)
	health = maxi(health - amount, 1)
	health_changed.emit(health, max_health)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.6, 0.6), 0.05)
	tw.tween_property(sprite, "modulate", Color(1.0, 0.9, 0.75) if _state == STUNNED else Color.WHITE, 0.2)
	if _state == STUNNED:
		return
	_hits_taken += 1
	_hits_clock = 1.2
	_away = _ground_away(from_position)
	if _hits_taken >= 3:
		_hits_taken = 0
		_enter(BACK_OFF, 0.32)      # out of the combo, then straight back in
		_cool = 0.0
	elif _hits_taken == 1 and _state != STRIKE and _state != WIND_UP:
		# only the first blow of a run makes him flinch, and never once his sword is
		# up: then it is parry or dodge
		_enter(STAGGER, 0.28)
		_pose(COIL)


## From his ready stance he turns a blow aside with his sword and answers at once.
func _block(from_position: Vector2) -> void:
	_face(from_position - global_position)
	_enter(WIND_UP, windup_time * 0.7)
	_pose(COIL)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(2.0, 1.8, 1.3), 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, windup_time * 0.7 - 0.06)


func _enter(s: int, secs: float) -> void:
	_state = s
	_left = secs


func _spar(delta: float, p: Node2D) -> void:
	_t += delta
	_left -= delta
	_cool = maxf(_cool - delta, 0.0)
	_hits_clock -= delta
	if _hits_clock <= 0.0:
		_hits_taken = 0
	if p == null:
		return
	var to := p.global_position - global_position
	var dist := Vector2(to.x, to.y * 2.0).length()
	var bob := 0.0
	velocity = Vector2.ZERO
	match _state:
		READY:
			_face(to)
			if dist > attack_range:
				velocity = to.normalized() * spar_speed * Vector2(1.0, 0.75)
				bob = absf(sin(_t * 9.0)) * 1.4
			elif _cool <= 0.0:
				_enter(WIND_UP, windup_time)
				_pose(COIL)
				# the glint: now is the time to parry
				var tw := create_tween()
				tw.tween_property(sprite, "modulate", Color(2.0, 1.8, 1.3), 0.08)
				tw.tween_property(sprite, "modulate", Color.WHITE, windup_time - 0.08)
			_pose(OPEN if _state == READY else COIL)
		WIND_UP:
			_face(to)
			_pose(RAISED if _left < windup_time * 0.5 else COIL)
			sprite.offset.x = _base.x + sin(_t * 60.0) * 0.5
			if _left <= 0.0:
				_enter(STRIKE, 0.22)
				_pose(CUT)
				_cut(p, to, dist)
		STRIKE:
			_pose(FOLLOW if _left < 0.11 else CUT)
			var f := _facing_vec()
			velocity = Vector2(f.x, f.y * 0.5) * 140.0 * clampf(_left / 0.22, 0.0, 1.0)
			if _left <= 0.0:
				_enter(RECOVER, 0.5)
		RECOVER:
			_pose(SETTLE)
			if _left <= 0.0:
				_cool = randf_range(0.5, 1.1)
				if randf() < 0.4:
					_away = _ground_away(p.global_position)
					_enter(BACK_OFF, 0.35)
				else:
					_enter(READY, 0.0)
		BACK_OFF:
			velocity = _away * 150.0
			_pose(OPEN)
			if _left <= 0.0:
				_enter(READY, 0.0)
		STAGGER:
			velocity = _away * 60.0 * clampf(_left / 0.28, 0.0, 1.0)
			if _left <= 0.0:
				_enter(READY, 0.0)
				_cool = maxf(_cool, 0.35)
		STUNNED:
			bob = sin(_t * 12.0) * 0.8
			if _left <= 0.0:
				sprite.modulate = Color.WHITE
				_away = _ground_away(p.global_position)
				_enter(BACK_OFF, 0.3)
	if _state != WIND_UP:
		sprite.offset = _base + Vector2(0, -bob)
	move_and_slide()


## Lands the cut if the player is in reach and in front of him.
func _cut(p: Node2D, to: Vector2, dist: float) -> void:
	if dist > strike_reach or p.get("dead") == true or not p.has_method("take_hit"):
		return
	if dist > 12.0 and Vector2(to.x, to.y * 2.0).normalized().dot(_facing_vec()) < 0.3:
		return
	var hp := int(p.get("health"))
	if hp > 1:
		p.take_hit(mini(damage, hp - 1), global_position)


func _facing_vec() -> Vector2:
	return Vector2.RIGHT.rotated(DIRS.find(facing) * TAU / 8.0)


## Screen direction (squashed on the ground) away from a point; back toward the
## middle of the arena instead when that would take him out of it.
func _ground_away(from: Vector2) -> Vector2:
	var v := global_position - from
	var g := Vector2(v.x, v.y * 2.0).normalized()
	if g == Vector2.ZERO:
		g = Vector2.DOWN
	if _arena != Vector2.INF:
		var off := global_position + Vector2(g.x, g.y * 0.5) * 45.0 - _arena
		var home := _arena - global_position
		if Vector2(off.x, off.y * 2.0).length() > _arena_radius and home.length() > 1.0:
			g = Vector2(home.x, home.y * 2.0).normalized()
	return Vector2(g.x, g.y * 0.5)


## Holds one frame of his "train" animation toward `facing`.
func _pose(frame: int) -> void:
	var a := "train_" + facing
	if sprite.animation != a:
		sprite.animation = a
	if sprite.is_playing():
		sprite.pause()
	sprite.frame = frame
