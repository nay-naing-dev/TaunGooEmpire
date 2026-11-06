extends "res://characters/npcs/bandit/bandit.gd"
## Nga Tay, leader of the forest outlaws (grain_quest.gd). The brute's body, with a
## health bar (HUD show_foe) and a fight the story scene starts and ends:
## - start_fight() / stop_fight(). Blows only count during the fight.
## - He doesn't die: at yield_at of his health he gives up (yielded); what happens
##   to him then is the player's choice.
## - A perfect parry stuns him, like the trainer.

signal health_changed(current: int, maximum: int)
signal yielded

@export var display_name := "Nga Tay"
@export_range(0.0, 1.0, 0.05) var yield_at := 0.3

var fighting := false
var _stunned := 0.0


func start_fight() -> void:
	fighting = true
	aggressive = true
	state = CHASE


func stop_fight() -> void:
	fighting = false
	aggressive = false
	state = WAIT
	home = global_position
	velocity = Vector2.ZERO
	_stunned = 0.0
	sprite.modulate = Color.WHITE


func is_stunned() -> bool:
	return _stunned > 0.0


func stun(secs: float) -> void:
	if not fighting:
		return
	_stunned = secs
	state = WAIT
	velocity = Vector2.ZERO
	_play("idle")
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.7, 1.6, 1.2), 0.05)
	tw.tween_property(sprite, "modulate", Color(1.0, 0.9, 0.75), 0.3)


func _physics_process(delta: float) -> void:
	if _stunned > 0.0:
		_stunned -= delta
		sprite.offset = _base + Vector2(sin(_t * 12.0) * 0.8, 0)
		_t += delta
		if _stunned <= 0.0:
			sprite.modulate = Color.WHITE
			sprite.offset = _base
			state = CHASE
		return
	super(delta)


func take_hit(amount: int, _from_position: Vector2) -> void:
	if not fighting:
		return
	var floor_at := ceili(max_health * yield_at)
	health = maxi(health - amount, floor_at)
	health_changed.emit(health, max_health)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.8, 0.6, 0.6), 0.05)
	tw.tween_property(sprite, "modulate", Color(1.0, 0.9, 0.75) if is_stunned() else Color.WHITE, 0.2)
	if health <= floor_at:
		fighting = false
		yielded.emit.call_deferred()  # not in the middle of the player's swing
