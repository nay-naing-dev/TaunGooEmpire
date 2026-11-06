extends Cutscene
class_name GrainQuest
## The forest half of the grain quests, after the trainer's orders (grain_orders.gd).
## Quest "Grain for the March": the player carries a rice bag (mc_warrior set_carrying)
## along the road. The forest is quiet: its usual bandits are gone while this quest runs.
## Quest "The Price of Grain": at the river they jump him. Nga Tay and five outlaws appear
## around him (Bandit1..5 markers), he drops the bag and fights. Nga Tay gives up at 30%
## of his health; when the outlaws are down too the player chooses: hand him over, let
## him go, or kill him (kill_nga_tay cinematic). Game.flags[FATE] keeps the choice,
## Game.flags[SPARED] is set if he went free. Then pick up the bag (E) and take it
## back to the trainer (grain_orders.gd).
## How far it got is kept in Game.flags[STAGE]: fall in the fight and the player wakes up
## on the Retry marker with the bag, and walks into it again.
## The Marker2D children are where everything stands; move them in the editor.

const STAGE := "grain_stage"
enum { ORDERS, CARRY, RECOVER, RETURN, DONE }
const FATE := "nga_tay_fate"
const SPARED := "nga_tay_spared"

const QUEST := "grain_for_the_march"
const QUEST_TITLE := "Grain for the March"
const OBJECTIVES := [
	"Take the rice bag from the Quartermaster",
	"Carry it along the forest road to the river",
]
const QUEST_CAMP := "the_price_of_grain"
const QUEST_CAMP_TITLE := "The Price of Grain"
const OBJECTIVES_CAMP := [
	"Defeat the outlaws",
	"Defeat Nga Tay",
	"Decide what happens to him",
	"Pick up the rice bag and report to the trainer",
]
const OUTLAWS := 5
const RAIDER := "res://characters/npcs/bandit_raider/bandit_raider.tscn"
const NGA_TAY := "res://characters/npcs/nga_tay/nga_tay.tscn"
const KILL_CINEMATIC := "res://cutscenes/kill_nga_tay/kill_cutscene.tscn"
const SACK_TEXTURE := "res://environment/village/props/sack.png"
## The cinematic is a rainy night: it happens at this hour, and it's still night after it.
const KILL_HOUR := 21.0
## They jump him as he crosses this band through the Ambush marker: (half width, half height).
## Tall enough that he can't get to the bridge around it.
const AMBUSH_BAND := Vector2(30.0, 220.0)

var _bag: QuestSpot
var _outlaws: Array[Node2D] = []
var _outlaws_left := 0
var _boss_down := false
var _busy := false


func _ready() -> void:
	_build.call_deferred()


func _stage() -> int:
	return int(Game.flags.get(STAGE, -1))


## Sets up what the current stage needs (arriving in the map, or back after falling).
func _build() -> void:
	var s := _stage()
	if s < CARRY or s > RETURN:
		return
	for b in get_tree().get_nodes_in_group("bandit"):
		b.queue_free()
	var p := _player()
	if s == CARRY and p:
		p.set_carrying(true)
	if s == RECOVER:
		_drop_bag()


func _process(_delta: float) -> void:
	var p := _player()
	if _busy or p == null or _stage() != CARRY or get_tree().paused or Game.in_dialogue():
		return
	var v := p.global_position - _at("Ambush")
	if absf(v.x) < AMBUSH_BAND.x and absf(v.y) < AMBUSH_BAND.y:
		_ambush()


func _hold() -> Node2D:
	var p := _player()
	Game.cutscene = true
	_busy = true
	_freeze(p)
	return p


func _release() -> void:
	_player().set_physics_process(true)
	Game.cutscene = false
	_busy = false


# --------------------------------------------------------------------------
# The ambush
# --------------------------------------------------------------------------

func _ambush() -> void:
	var p := _hold()
	var hud = get_parent().hud
	Game.quests.complete_objective(QUEST, 1)
	Game.quests.finish(QUEST)
	Game.quests.start(QUEST_CAMP, QUEST_CAMP_TITLE, PackedStringArray(OBJECTIVES_CAMP))

	hud.show_banner("AMBUSH!", Color(1, 0.4, 0.3), 0.8)
	_outlaws_left = OUTLAWS
	for i in OUTLAWS:
		var b := _spawn("Bandit%d" % (i + 1), RAIDER, "s")
		get_parent()._add_sun_shadows(b)
		b.died.connect(func(): _outlaws_left -= 1)
		_outlaws.append(b)
	var ng := _spawn("NgaTayStart", NGA_TAY, "e")
	get_parent()._add_sun_shadows(ng)
	await _wait(0.2)
	_look(p, ng)
	for b in _outlaws:
		_look(b, p)
	await _wait(0.5)
	p.set_carrying(false)  # he drops the bag where he stands
	(get_node("Bag") as Node2D).global_position = p.global_position + Vector2(10, 6)
	_drop_bag()
	await _walk_all([[ng, _at("NgaTay")]])
	_look(ng, p)
	await _say(ng.display_name, ["That badge... So the army has sent more new recruits."])
	var pick := await _ask(ng.display_name, [
		"I followed the King's orders once, just like you. Don't think holding a sword means you understand war.",
	], [
		"That's the army's rice. Stand aside.",
		"You were a soldier once. Why are you a bandit now?",
	])
	if pick == 1:
		await _say(ng.display_name, [
			"On the battlefield, only the order matters. Nobody asks about the lives of the people left behind.",
		])
	await _fight(ng)


func _fight(ng: Node2D) -> void:
	var p := _player()
	var hud = get_parent().hud
	hud.show_banner("FIGHT!", Color(1, 0.85, 0.45), 0.6)
	await _wait(0.6)
	Game.next_spawn = "GrainQuest/Retry"  # if he falls, he wakes up here and goes again
	ng.yielded.connect(func():
		ng.stop_fight()
		hud.hide_foe()
		Game.quests.complete_objective(QUEST_CAMP, 1)
		_boss_down = true)
	ng.start_fight()
	hud.show_foe(ng)
	for b in _outlaws:
		b.ambush()
	p.set_physics_process(true)
	Game.cutscene = false
	while not _boss_down or _outlaws_left > 0:
		await get_tree().physics_frame
	Game.next_spawn = ""
	Game.quests.complete_objective(QUEST_CAMP, 0)
	_hold()
	_look(ng, p)
	_look(p, ng)
	await _wait(0.5)
	await _say(ng.display_name, ["Enough! Enough. Don't let any more of my men die. Take the rice."])
	_decide(ng)


func _decide(ng: Node2D) -> void:
	var me: String = Game.player_name
	var pick := await _ask("", ["Nga Tay stands before you with his blade lowered. What do you do?"], [
		"Bind him and hand him over",
		"Let him go",
		"Kill him",
	])
	match pick:
		0:
			Game.flags[FATE] = "bound"
			await _say(me, ["I'm taking you to the camp. The judges will decide."])
			await _say(ng.display_name, ["We are what's left over from that war too. Remember that."])
		1:
			Game.flags[FATE] = "released"
			Game.flags[SPARED] = true
			await _say(me, ["Lay down your arms and leave this land. And don't touch the army's provisions again."])
			await _say(ng.display_name, [
				"I won't forget you. But the things you'll see in the south... I can't wish those on you.",
			])
		2:
			Game.flags[FATE] = "killed"
	Game.quests.complete_objective(QUEST_CAMP, 2)
	if pick == 2:
		await _kill_cinematic(ng)
	else:
		await _fade(1.0, 0.6)
		ng.queue_free()
		await _fade(0.0, 0.6)
	Game.flags[STAGE] = RECOVER
	Game.player_says("The rice bag. It has to get back to the trainer.")
	_release()


## Plays cutscenes/kill_nga_tay. It shows the live map behind some of its shots (dark,
## through its own overlay), so the black screen has to be off while it runs; when it
## ends the screen is black again in the same frame and fades up on the empty road.
func _kill_cinematic(ng: Node2D) -> void:
	await _fade(1.0, 0.6)
	Game.set_hour(KILL_HOUR)
	await get_tree().process_frame  # the world lights itself for the new hour
	var cs: CanvasLayer = load(KILL_CINEMATIC).instantiate()
	get_tree().root.add_child(cs)
	cs.play()
	await _fade(0.0, 0.0)
	await cs.finished
	await _fade(1.0, 0.0)
	ng.queue_free()
	await _wait(0.8)
	await _fade(0.0, 1.2)


# --------------------------------------------------------------------------
# The rice bag on the ground
# --------------------------------------------------------------------------

func _drop_bag() -> void:
	_bag = QuestSpot.new(44.0)
	_bag.position = _at("Bag")
	_bag.used = _pick_up_bag
	var body := Sprite2D.new()
	body.texture = load(SACK_TEXTURE)
	body.centered = false
	body.offset = Vector2(-14, -34)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag.add_child(body)
	_objects().add_child(_bag)


func _pick_up_bag() -> void:
	if _stage() != RECOVER:
		return  # still fighting
	_bag.queue_free()
	_player().set_carrying(true)
	Game.flags[STAGE] = RETURN
	Game.player_says("Back to the trainer at the training ground.", 4.0)
