extends Node2D
## Cutscene "The King's Levy" (village). Plays once: the first time the village is
## open at 6:00 on day 2 or later (woken up in bed, or after a night outside).
## - The player can't move while it plays (Game.cutscene).
## - The royal summoner (King Bayinnaung's sprite), two archers, a cavalry rider and a
##   flag bearer suddenly appear in the middle of the village. The villagers gather
##   round them, Mother beside the player. The summoner reads the King's order, calls
##   the player forward and tells him he has been called up. Then the villagers drift
##   off whispering and the summoner leaves.
## - Afterwards it is 11:00, the player and Mother stand in front of their house and
##   the quest "The King's Levy" starts (Speak with Mother).
## The Marker2D children are where everyone stands; move them in the editor.
## <Name> = where a villager (node name in Objects) stands in the crowd,
## <Name>Start = where they come from and go back to.

const DONE := "kings_levy_done"
const QUEST := "kings_levy"
const QUEST_TITLE := "The King's Levy"
const OBJECTIVES := ["Speak with Mother"]
const SUMMONER := "Summoner"
const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
## Who arrives, by the marker they stand on.
const PARTY := {
	"Summoner": "res://characters/palace/king_bayinnaung/king_bayinnaung.tscn",
	"Archer1": "res://characters/palace/archer/archer.tscn",
	"Archer2": "res://characters/palace/archer/archer.tscn",
	"FlagBearer": "res://characters/palace/flag_bearer/flag_bearer.tscn",
	"Cavalry": "res://characters/palace/cavalry_rider/cavalry_rider.tscn",
}
## The direction the escort faces (toward the crowd).
const PARTY_FACING := "sw"
## What the villagers whisper as they go.
const WHISPERS := {
	"RicePorter": "The harvest isn't even in yet...",
	"VillageWoman": "Whose son will they take next?",
}

## Walking speed in the cutscene (pixels per second along the ground).
@export var walk_speed := 34.0

signal _said
var _running := false
var _black: ColorRect
var _party := {}


func _process(_delta: float) -> void:
	if _running or Game.flags.get(DONE, false) or not _due():
		return
	if get_tree().paused or Game.in_dialogue() or _player() == null:
		return
	for h in get_tree().get_nodes_in_group("house"):
		if h.get("_busy"):
			return  # walking in / out of a house: wait for the fade
	_play()


## 6:00 on day 2, or any time after.
func _due() -> bool:
	return Game.day > 2 or (Game.day == 2 and Game.hour >= 6.0)


func _play() -> void:
	_running = true
	Game.cutscene = true
	var clock_was: bool = Game.clock_running
	Game.clock_running = false
	var p := _player()
	_freeze(p)
	var mom := _objects().get_node_or_null("McMother") as Node2D
	var mom_name: String = mom.display_name if mom else "Mother"
	var me: String = Game.player_name
	var villagers: Array[Node2D] = []
	var homes := {}
	for a in get_tree().get_nodes_in_group("actor"):
		if a != mom and a.get("held") != null:
			villagers.append(a)
			homes[a] = a.global_position

	# --- set the stage while the screen is black
	await _fade(1.0, 0.6)
	for h in get_tree().get_nodes_in_group("house"):
		h.leave_now()
	_put(p, "PlayerStart", "se")
	if mom:
		mom.hold()
		_put(mom, "MotherStart", "se")
	for v in villagers:
		v.held = true
		if has_node(NodePath(str(v.name) + "Start")):
			_put(v, str(v.name) + "Start", "s")
	(p.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _wait(0.3)
	await _fade(0.0, 0.6)
	await _wait(0.8)

	# --- the summoner and his escort appear in the middle of the village
	for key in PARTY:
		_spawn(key)
	var s: Node2D = _party["Summoner"]
	await _wait(1.4)

	# --- everyone gathers round, Mother beside the player
	var moves := [[p, _at("Player")]]
	if mom:
		moves.append([mom, _at("Mother")])
	for v in villagers:
		if has_node(NodePath(str(v.name))):
			moves.append([v, _at(str(v.name))])
	await _walk_all(moves)
	for m in moves:
		_look(m[0], s)
	# frame the player and the escort together, above the dialogue box
	var cam := p.get_node("Camera2D") as Camera2D
	var mid := Vector2((p.global_position.x + s.global_position.x) * 0.5, s.global_position.y)
	create_tween().tween_property(cam, "offset", mid - (p.global_position + cam.position), 1.0) \
			.set_trans(Tween.TRANS_SINE)
	await _wait(0.8)

	if mom:
		_look(mom, p)
		_look(p, mom)
		await _say(mom_name, ["This is the summoner I told you about."])
		_look(mom, s)
		_look(p, s)
	await _say(SUMMONER, [
		"People of this village. I bring an order issued in the name of His Majesty, King Tabinshwehti.",
		"The royal army is gathering men for the King's service. This village, like others under the crown, must provide its share.",
		"Those called to service will receive their instructions. They must report for training and await further orders.",
	])

	# --- he comes up to the player and stops right in front of him
	var to_player := _ground_dir(s.global_position, p.global_position)
	await _walk_all([[s, p.global_position - to_player * 26.0]])
	_look(s, p)
	_look(p, s)
	await _say(SUMMONER, ["You. Step forward."])
	await _say(me, ["Are you speaking to me, sir?"])
	await _say(SUMMONER, ["State your name."])
	await _say(me, ["I'm %s." % me])
	_face(s, "s")  # looks down at the order
	await _wait(0.5)
	await _say("", ["The summoner checks the name on his document."])
	_look(s, p)
	await _say(SUMMONER, ["%s. You are called to serve His Majesty." % me])
	await _say(me, ["Me? But why?"])
	await _say(SUMMONER, ["You are among those required to answer the royal levy. Your name has been recorded for service."])
	await _say(me, ["But I've never been a soldier."])
	await _say(SUMMONER, ["That is why you will receive training. You are not expected to know everything before you begin."])
	if mom:
		_look(s, mom)
		await _say(mom_name, ["Sir, surely you can give us some time. He is needed at home."])
	await _say(SUMMONER, ["I understand, madam. But I have come to deliver the King's order, not to decide whether it should be obeyed."])
	_look(s, p)
	await _wait(0.5)
	await _say(SUMMONER, ["Report to the trainer. You will be informed when the men are to assemble for the march."])

	# --- he steps away; the villagers drift off, whispering
	_walk_all([[s, _at("Summoner")]])
	_disperse(villagers)
	await _wait(1.8)
	if mom:
		_look(p, mom)
		_look(mom, p)
	await _say(me, ["Mother..."])
	await _say(mom_name, ["Come home with me. We must talk."])

	# --- as he turns to leave, the summoner calls after him
	var home := _ground_dir(p.global_position, _at("PlayerHome"))
	var leave := [[p, p.global_position + home * 22.0]]
	if mom:
		leave.append([mom, mom.global_position + home * 22.0])
	await _walk_all(leave)
	await _say(SUMMONER, ["Young man."])
	_look(p, s)
	await _wait(0.4)
	await _say(SUMMONER, ["Do not mistake your lack of experience for an excuse to neglect your training. Learn what you can while you have the opportunity."])
	await _walk_all([[s, _at("SummonerLeave")]])
	_look(p, s)
	await _wait(1.0)

	# --- later that morning, in front of the house
	await _fade(1.0, 0.8)
	for key in _party:
		_party[key].queue_free()
	_party.clear()
	for v in villagers:
		v.global_position = homes[v]
		v.held = false
	Game.flags[DONE] = true
	Game.flags["mother_intro_done"] = true  # the news is out either way
	if Game.hour < 11.0:
		Game.set_hour(11.0)
	Game.clock_running = clock_was
	Game.quests.start(QUEST, QUEST_TITLE, PackedStringArray(OBJECTIVES))
	if mom:
		mom.wait_in_yard()
	_put(p, "PlayerHome", _dir_to(mom.global_position - _at("PlayerHome")) if mom else "s")
	cam.offset = Vector2.ZERO
	cam.reset_smoothing()
	p.set_physics_process(true)
	Game.cutscene = false
	await _wait(0.3)
	await _fade(0.0, 0.6)


## The villagers walk back where they came from, whispering.
func _disperse(villagers: Array[Node2D]) -> void:
	var moves := []
	for v in villagers:
		var bubble = v.get("_bubble")
		if bubble and WHISPERS.has(str(v.name)):
			bubble.say(WHISPERS[str(v.name)])
		if has_node(NodePath(str(v.name) + "Start")):
			moves.append([v, _at(str(v.name) + "Start")])
	await _walk_all(moves)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

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


## Black screen in (to = 1) or out (to = 0).
func _fade(to: float, secs: float) -> void:
	if _black == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_black = ColorRect.new()
		_black.color = Color(0, 0, 0, 0)
		_black.set_anchors_preset(Control.PRESET_FULL_RECT)
		_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_black)
	var t := create_tween()
	t.tween_property(_black, "color:a", to, secs)
	await t.finished


## The player stops and stands still; the cutscene moves and turns him.
func _freeze(p: Node2D) -> void:
	p.set_physics_process(false)
	p.set("velocity", Vector2.ZERO)
	var dust := p.get_node_or_null("Dust") as CPUParticles2D
	if dust:
		dust.emitting = false
	var spr := p.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr:
		spr.speed_scale = 1.0
	_face(p, _facing_of(p))


func _spawn(key: String) -> void:
	var a: Node2D = load(PARTY[key]).instantiate()
	a.set("start_facing", PARTY_FACING)
	a.position = _at(key)
	a.modulate.a = 0.0
	_objects().add_child(a)
	create_tween().tween_property(a, "modulate:a", 1.0, 0.25)
	_puff(a.global_position)
	_party[key] = a


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
