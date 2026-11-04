extends Cutscene
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
## The day it played (the summoner comes back for the levy the morning after: time_to_go.gd).
const DAY := "kings_levy_day"
const QUEST := "kings_levy"
const QUEST_TITLE := "The King's Levy"
const OBJECTIVES := ["Speak with Mother"]
const SUMMONER := "Summoner"
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

var _running := false
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
		_party[key] = _spawn(key, PARTY[key], PARTY_FACING)
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
	Game.flags[DAY] = Game.day
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
