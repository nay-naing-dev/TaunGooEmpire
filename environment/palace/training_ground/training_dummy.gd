extends StaticBody2D
## Training dummy: a rope-wrapped post with a sack head and a wooden cross-arm.
## It can't be destroyed.
## - Hit it (it is in group "enemy", so the warrior aims at it and his blows land):
##   it rocks on its base, straw flies and `struck` is emitted.
## - swinging = true: while the player stands within reach it winds the arm back
##   ("!" over its head) and swings it round at him every swing_interval seconds.
##   A perfect parry stuns it for a moment (stun(), like an enemy).
## Its blows never take the player below 1 health.

signal struck(amount: int)
## The arm came round at the player standing in reach (he may have parried or dodged it).
signal swung

@export var swinging := false
@export var swing_interval := 2.2
## How close the player must be for the arm to reach him (ground distance, up / down counts double).
@export var reach := 44.0
@export var damage := 6
## Where the arm turns, above the base.
@export var arm_height := 60.0
@export var arm_length := 21.0

const SpeechBubble := preload("res://scripts/speech_bubble.gd")
const WINDUP := 0.6
const SWING := 0.16
const SETTLE := 0.5
const OUTLINE := Color(0.2, 0.12, 0.08)
const WOOD := Color(0.55, 0.36, 0.2)
const WOOD_LIT := Color(0.7, 0.5, 0.29)
const STRAW := Color(0.85, 0.71, 0.47)

@onready var body: Sprite2D = $Sprite2D
var _arms: Array[Node2D] = []
## Ground angle of the first arm (0 = east, PI / 2 = toward the camera); the other is opposite.
var _angle := 0.0
var _spin := 0.0
var _wobble := 0.0
var _wobble_v := 0.0
var _cool := 1.2
var _stun := 0.0
var _swing_t := -1.0          # time into the current swing, -1 = resting
var _back := 0.0
var _to := 0.0
var _hit_done := false
var _bubble: SpeechBubble
var _straw: CPUParticles2D


func _ready() -> void:
	add_to_group("enemy")
	for i in 2:
		var arm := Node2D.new()
		arm.position = Vector2(0, -arm_height)
		arm.draw.connect(_draw_arm.bind(arm, i))
		body.add_child(arm)
		_arms.append(arm)
	_bubble = SpeechBubble.new()
	_bubble.head_height = arm_height + 34.0
	add_child(_bubble)
	_straw = CPUParticles2D.new()
	_straw.position = Vector2(0, -arm_height + 14.0)
	_straw.z_index = 2
	_straw.emitting = false
	_straw.one_shot = true
	_straw.explosiveness = 0.95
	_straw.amount = 12
	_straw.lifetime = 0.55
	_straw.spread = 70.0
	_straw.gravity = Vector2(0, 180)
	_straw.initial_velocity_min = 40.0
	_straw.initial_velocity_max = 90.0
	_straw.scale_amount_min = 1.0
	_straw.scale_amount_max = 2.0
	_straw.color = STRAW
	add_child(_straw)


func is_stunned() -> bool:
	return _stun > 0.0


## A perfect parry knocks the arm away: it hangs loose for secs.
func stun(secs: float) -> void:
	_stun = secs
	_swing_t = -1.0
	_bubble.mark("")
	_spin = 7.0 * signf(_spin if _spin != 0.0 else 1.0)
	_rock(0.25)
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(1.6, 1.5, 1.1), 0.05)
	tw.tween_property(body, "modulate", Color.WHITE, 0.4)


func take_hit(amount: int, from_position: Vector2) -> void:
	_rock(clampf(amount * 0.012, 0.06, 0.3) * (1.0 if from_position.x < global_position.x else -1.0))
	_straw.direction = Vector2(signf(global_position.x - from_position.x), -0.6)
	_straw.restart()
	_straw.emitting = true
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(1.5, 1.35, 1.15), 0.04)
	tw.tween_property(body, "modulate", Color.WHITE, 0.2)
	struck.emit(amount)


## Pushes the top of the post sideways (radians a second); it springs back.
func _rock(kick: float) -> void:
	_wobble_v += kick * 9.0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _in_reach(p: Node2D) -> bool:
	if p == null or p.get("dead") == true:
		return false
	var v := p.global_position - global_position
	return Vector2(v.x, v.y * 2.0).length() < reach


func _process(delta: float) -> void:
	# the post rocks on its base like a spring
	_wobble_v += (-_wobble * 160.0 - _wobble_v * 9.0) * delta
	_wobble += _wobble_v * delta
	body.rotation = _wobble
	var p := _player()
	if _stun > 0.0:
		_stun -= delta
		_angle += _spin * delta
		_spin = move_toward(_spin, 0.0, 6.0 * delta)
	elif _swing_t >= 0.0:
		_swing(delta, p)
	else:
		_angle += _spin * delta
		_spin = move_toward(_spin, 0.0, 3.0 * delta)
		if swinging and _in_reach(p):
			_cool -= delta
			if _cool <= 0.0:
				_wind_up(p)
		else:
			_cool = maxf(_cool, 0.8)
	for i in _arms.size():
		var a := _angle + PI * i
		_arms[i].show_behind_parent = sin(a) < 0.0   # pointing away from us: behind the post
		_arms[i].queue_redraw()


## The arm swings so that it passes the player halfway through the swing.
func _wind_up(p: Node2D) -> void:
	var v := p.global_position - global_position
	var at := Vector2(v.x, v.y * 2.0).angle()
	var way := 1.0 if randf() < 0.5 else -1.0
	# wind back the short way round (whichever arm is closer), then swing through `at`
	_back = _angle + wrapf(at - way * 1.9 - _angle, -PI * 0.5, PI * 0.5)
	_to = _back + way * 3.8
	_swing_t = 0.0
	_hit_done = false
	_spin = 0.0
	_bubble.mark("!")


func _swing(delta: float, p: Node2D) -> void:
	var from := _angle
	_swing_t += delta
	if _swing_t < WINDUP:
		# pulls the arm back, creaking
		_angle = lerp_angle(_angle, _back, 1.0 - exp(-10.0 * delta))
		body.position.x = sin(_swing_t * 70.0) * 0.4
	elif _swing_t < WINDUP + SWING:
		var k := (_swing_t - WINDUP) / SWING
		_angle = lerpf(_back, _to, k)
		body.position.x = 0.0
		if not _hit_done and k >= 0.5:
			_hit_done = true
			_bubble.mark("")
			_strike(p)
	elif _swing_t < WINDUP + SWING + SETTLE:
		_angle = lerpf(_to, _to + (_to - _back) * 0.12, smoothstep(0.0, SETTLE, _swing_t - WINDUP - SWING))
	else:
		_swing_t = -1.0
		_cool = swing_interval
		_spin = 0.0
	_spin = (_angle - from) / maxf(delta, 0.0001) * 0.2


func _strike(p: Node2D) -> void:
	_rock(0.08 * signf(_to - _back))
	if not _in_reach(p):
		return
	if p.has_method("take_hit") and int(p.get("health")) > 1:
		p.take_hit(mini(damage, int(p.get("health")) - 1), global_position)
	swung.emit()


func _draw_arm(arm: Node2D, i: int) -> void:
	var a := _angle + PI * i
	var tip := Vector2(cos(a), sin(a) * 0.5) * arm_length
	arm.draw_line(Vector2.ZERO, tip, OUTLINE, 4.0)
	arm.draw_line(Vector2.ZERO, tip, WOOD, 2.0)
	arm.draw_line(Vector2(0, -0.5), tip + Vector2(0, -0.5), WOOD_LIT, 1.0)
	# straw-padded fist at the end
	arm.draw_circle(tip, 3.4, OUTLINE)
	arm.draw_circle(tip, 2.5, STRAW)
	arm.draw_circle(tip + Vector2(-0.7, -0.7), 1.0, STRAW.lightened(0.3))
	if not arm.show_behind_parent:
		arm.draw_circle(Vector2.ZERO, 2.2, OUTLINE)  # the peg it turns on
		arm.draw_circle(Vector2.ZERO, 1.2, WOOD_LIT)
