extends Cutscene
## Cutscene "Time to Go" (village). Plays once: the first time the village is open at
## 6:00 the morning after the King's Levy (day 3 at the earliest).
## - The player can't move while it plays (Game.cutscene).
## - The summoner and his escort (the same as in kings_levy.gd) are back in the
##   middle of the village. The villagers gather round, Mother beside the player.
##   The summoner tells the player it is time to go, Mother says goodbye (that settles
##   the King's Levy quest) and they set off.
## - The screen blinks to black and the player is on the training ground by the
##   palace, MARCH_HOURS later, where training_day.gd takes over.
## The Marker2D children are where everyone stands; move them in the editor.
## <Name> = where a villager (node name in Objects) stands in the crowd,
## <Name>Start = where they come from.

const KingsLevy := preload("res://scripts/cutscenes/kings_levy.gd")
const DONE := "time_to_go_done"
const SUMMONER := "Summoner"
## How long the march to the palace takes (game hours).
const MARCH_HOURS := 2.0

var _running := false
var _party := {}


func _process(_delta: float) -> void:
	if _running or Game.flags.get(DONE, false) or not Game.flags.get(KingsLevy.DONE, false) or not _due():
		return
	if get_tree().paused or Game.in_dialogue() or _player() == null:
		return
	for h in get_tree().get_nodes_in_group("house"):
		if h.get("_busy"):
			return  # walking in / out of a house: wait for the fade
	_play()


## 6:00 the morning after the King's Levy, day 3 at the earliest, or any time after.
func _due() -> bool:
	var first := maxi(3, int(Game.flags.get(KingsLevy.DAY, 2)) + 1)
	return Game.day > first or (Game.day == first and Game.hour >= 6.0)


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
	for a in get_tree().get_nodes_in_group("actor"):
		if a != mom and a.get("held") != null:
			villagers.append(a)

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
	var cam := p.get_node("Camera2D") as Camera2D
	cam.reset_smoothing()
	await _wait(0.3)
	await _fade(0.0, 0.6)
	await _wait(0.6)

	# --- the summoner and his escort are back in the middle of the village
	for key in KingsLevy.PARTY:
		_party[key] = _spawn(key, KingsLevy.PARTY[key], KingsLevy.PARTY_FACING)
	var s: Node2D = _party[SUMMONER]
	await _wait(1.2)

	# --- everyone gathers round again, Mother beside the player
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
	var mid := Vector2((p.global_position.x + s.global_position.x) * 0.5, s.global_position.y)
	create_tween().tween_property(cam, "offset", mid - (p.global_position + cam.position), 1.0) \
			.set_trans(Tween.TRANS_SINE)
	await _wait(0.8)

	await _say(SUMMONER, [
		"People of this village. Those called by the King's levy were told to await further orders.",
		"The orders have come. The men leave today.",
	])

	# --- he comes up to the player
	var to_player := _ground_dir(s.global_position, p.global_position)
	await _walk_all([[s, p.global_position - to_player * 26.0]])
	_look(s, p)
	_look(p, s)
	await _say(SUMMONER, ["%s. It's time to go." % me])
	await _say(me, ["Now? This morning?"])
	await _say(SUMMONER, [
		"The trainer is waiting for you at the training ground beside the palace.",
		"He will put a blade in your hand and teach you how to use it, before anyone asks you to.",
	])

	# --- Mother says goodbye
	if mom:
		_look(p, mom)
		_look(mom, p)
		await _say(mom_name, [
			"So soon...",
			"Eat when they feed you. Sleep when they let you. And listen to your trainer, son.",
			"Then come back to me.",
		])
		await _say(me, ["I will, Mother. I promise."])
	if Game.quests.is_active(KingsLevy.QUEST):
		Game.quests.complete_objective(KingsLevy.QUEST)  # she has had her say
		Game.quests.finish(KingsLevy.QUEST)
	_look(p, s)
	await _wait(0.4)
	await _say(SUMMONER, ["Come. We march."])

	# --- they set off together toward March; the screen blinks and they are at the palace
	var way := _ground_dir(p.global_position, _at("March"))
	_fade(1.0, 1.4)
	await _walk_all([[s, s.global_position + way * 50.0], [p, p.global_position + way * 45.0]])
	await _fade(1.0, 0.2)
	Game.flags[DONE] = true
	Game.flags[TrainingDay.STAGE] = TrainingDay.ARRIVE
	Game.set_hour(Game.hour + MARCH_HOURS)
	Game.clock_running = clock_was
	Game.next_spawn = TrainingDay.ARRIVE_MARKER
	Game.go(Game.WORLD)
