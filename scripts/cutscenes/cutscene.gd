extends Node2D
class_name Cutscene
## What the story scenes (scripts/cutscenes/) share: people stand on this node's
## Marker2D children, the scene walks and turns them, fades the screen and plays
## the dialogue. Works on the player, Mother, villagers and the palace characters
## (anything with an AnimatedSprite2D; `facing` as an index or a name, or for
## villagers the animation is the direction).

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Walking speed in the cutscene (pixels per second along the ground).
@export var walk_speed := 34.0

signal _said
signal _picked(index: int)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _objects() -> Node:
	return get_node("../Objects")


func _at(marker: String) -> Vector2:
	return (get_node(marker) as Node2D).global_position


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _say(who: String, lines: Array) -> void:
	Game.dialogue(who, PackedStringArray(lines), func(): _said.emit())
	await _said


## The lines with choices under the last one; returns the index the player picked.
func _ask(who: String, lines: Array, choices: Array) -> int:
	Game.dialogue(who, PackedStringArray(lines), func(i: int): _picked.emit(i), PackedStringArray(choices))
	return await _picked


## Black screen in (to = 1) or out (to = 0). It stays black through a change of map.
func _fade(to: float, secs: float) -> void:
	await Game.fade(to, secs)


## The player stops and stands still; the cutscene moves and turns him.
func _freeze(p: Node2D) -> void:
	p.set_physics_process(false)
	if p.has_method("stand"):
		p.stand()  # the warrior: out of a swing / parry / dodge
	p.set("velocity", Vector2.ZERO)
	var dust := p.get_node_or_null("Dust") as CPUParticles2D
	if dust:
		dust.emitting = false
	var spr := p.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr:
		spr.speed_scale = 1.0
	_face(p, _facing_of(p))


## Someone appears on a marker in a puff of dust, facing dir.
func _spawn(marker: String, scene: String, dir: String) -> Node2D:
	var a: Node2D = load(scene).instantiate()
	a.set("start_facing", dir)
	a.position = _at(marker)
	a.modulate.a = 0.0
	_objects().add_child(a)
	create_tween().tween_property(a, "modulate:a", 1.0, 0.25)
	_puff(a.global_position)
	return a


## A burst of dust where someone appears.
func _puff(at: Vector2) -> void:
	var dust := CPUParticles2D.new()
	dust.position = at + Vector2(0, -6)
	dust.z_index = 1
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 28
	dust.lifetime = 0.7
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 10.0
	dust.direction = Vector2(0, -1)
	dust.spread = 180.0
	dust.gravity = Vector2(0, -10)
	dust.initial_velocity_min = 15.0
	dust.initial_velocity_max = 40.0
	dust.damping_min = 30.0
	dust.damping_max = 50.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.78, 0.62, 0.8))
	ramp.set_color(1, Color(0.86, 0.78, 0.62, 0.0))
	dust.color_ramp = ramp
	_objects().add_child(dust)
	dust.emitting = true
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)


func _put(a: Node2D, marker: String, dir: String) -> void:
	a.global_position = _at(marker)
	_face(a, dir)


## Direction on the ground from a to b (screen vector, up / down squashed).
func _ground_dir(a: Vector2, b: Vector2) -> Vector2:
	var g := Vector2(b.x - a.x, (b.y - a.y) * 2.0).normalized()
	return Vector2(g.x, g.y * 0.5)


func _dir_to(v: Vector2) -> String:
	return DIRS[wrapi(roundi(Vector2(v.x, v.y * 2.0).angle() / (TAU / 8.0)), 0, 8)]


func _look(a: Node2D, at: Node2D) -> void:
	_face(a, _dir_to(at.global_position - a.global_position))


## Turns anyone here: the player (facing index), Mother and the escort (facing name),
## villagers (their animation is the direction).
func _face(a: Node2D, dir: String) -> void:
	_set_facing(a, dir)
	_anim(a, "idle", dir)


func _set_facing(a: Node2D, dir: String) -> void:
	var f = a.get("facing")
	if f is int:
		a.set("facing", DIRS.find(dir))
	elif f is String:
		a.set("facing", dir)


func _facing_of(a: Node2D) -> String:
	var f = a.get("facing")
	if f is int:
		return DIRS[f]
	if f is String:
		return f
	var spr := a.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return str(spr.animation).get_slice("_", 1) if spr and "_" in str(spr.animation) else (str(spr.animation) if spr else "s")


## Plays kind ("idle" / "walk") toward dir with whatever the character has
## (walk -> run -> idle -> just the direction, for villagers).
func _anim(a: Node2D, kind: String, dir: String) -> void:
	var spr := a.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		return
	var names := ["%s_%s" % [kind, dir]]
	if kind == "walk":
		names.append("run_" + dir)
	names.append_array(["idle_" + dir, dir])
	for n in names:
		if spr.sprite_frames.has_animation(n):
			if spr.animation != n:
				spr.play(n)
			# a run played at walking pace (the warrior has no walk)
			spr.speed_scale = 0.6 if kind == "walk" and n.begins_with("run") else 1.0
			return


## Walks everyone in moves ([character, target]) at once; returns when all are there.
## Their own scripts are paused meanwhile (the player's stays paused).
func _walk_all(moves: Array) -> void:
	var list := []
	for m in moves:
		var a: Node2D = m[0]
		var spr := a.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		list.append({"a": a, "to": m[1], "was": a.is_physics_processing(), "spr": spr,
				"base": spr.offset if spr else Vector2.ZERO, "done": false})
		a.set_physics_process(false)
	var t := 0.0
	var left := list.size()
	while left > 0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		left = 0
		for e in list:
			if e.done:
				continue
			var a: Node2D = e.a
			var d: Vector2 = e.to - a.global_position
			var dir := _dir_to(d)
			a.global_position += (d.normalized() * walk_speed * dt * Vector2(1.0, 0.75)).limit_length(d.length())
			_set_facing(a, dir)
			_anim(a, "walk", dir)
			var spr: AnimatedSprite2D = e.spr
			if spr and not spr.animation.begins_with("walk") and not spr.animation.begins_with("run"):
				spr.offset = e.base + Vector2(0, -absf(sin(t * 8.0)) * 1.5)  # no walk frames: step bob
			if a.global_position.distance_to(e.to) < 0.5:
				e.done = true
				if spr:
					spr.offset = e.base
				_face(a, dir)
			else:
				left += 1
	for e in list:
		e.a.set_physics_process(e.was)
