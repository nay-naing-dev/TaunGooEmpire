extends Cutscene
class_name TrainingDay
## Quest "Ready for Battle" on the palace training ground (after time_to_go.gd).
## 1. Arrival (cutscene): the player stands before the trainer, who hands him a sword.
##    In a blink the village boy is the warrior (Game.topdown_character, for good).
## 2. Lessons at the training dummy, one quest objective each, with a card at the top
##    of the screen counting them: left click to attack, right click to parry the
##    dummy's swinging arm, Space while moving to dodge.
## 3. A spar with the trainer. When either of them is near death (NEAR_DEATH of his
##    health) the trainer stops it and tells the player he is ready to fight in
##    the King's battles; the quest is done.
## How far it got is kept in Game.flags[STAGE]. Leave the palace halfway and the
## trainer has a "!" over him when you come back: talk to him (E) to go on.
## The Marker2D children are where everyone stands; move them in the editor.
## Trainer is his post (he drills there before and after); the spar starts on
## DuelTrainer / DuelPlayer and he keeps it around the middle of the two.

const STAGE := "training_stage"
enum { ARRIVE, ATTACK, PARRY, DODGE, DUEL, DONE }
## Where time_to_go.gd puts the player (Game.next_spawn).
const ARRIVE_MARKER := "TrainingDay/PlayerArrive"
const QUEST := "ready_for_battle"
const QUEST_TITLE := "Ready for Battle"
const OBJECTIVES := [
	"Strike the dummy (left click)",
	"Parry the dummy's swing (right click)",
	"Dodge while moving (Space)",
	"Spar with the trainer",
]
## For each lesson: what the card says and how many it takes.
const LESSONS := {
	ATTACK: ["Left click: attack the dummy", 6],
	PARRY: ["Right click: parry the dummy's swing", 3],
	DODGE: ["Space while moving: dodge", 3],
}
## The spar stops when either of them is down to this much of his health.
const NEAR_DEATH := 0.25

@export var trainer_path: NodePath = ^"../Objects/Trainer1"
@export var dummy_path: NodePath = ^"../Objects/TrainingDummy"

signal _counted
var _running := false
var _count := 0
var _need := 0
var _parried_now := false
var _hurt_now := false
var _card: PanelContainer
var _card_text: Label
var _card_count: Label


func _process(_delta: float) -> void:
	if _running or not Game.flags.has(STAGE) or _stage() >= DONE:
		return
	if get_tree().paused or Game.in_dialogue() or _player() == null:
		return
	_running = true
	if _stage() == ARRIVE:
		_run(false)
	else:
		_wait_for_talk()


func _stage() -> int:
	return int(Game.flags.get(STAGE, DONE))


func _trainer() -> Node2D:
	return get_node(trainer_path) as Node2D


func _dummy() -> Node2D:
	return get_node(dummy_path) as Node2D


func _who() -> String:
	return _trainer().display_name


## Back after leaving halfway: the trainer waits with a "!" until the player talks to him.
func _wait_for_talk() -> void:
	var t := _trainer()
	t.mark("!")
	t.talk = func():
		t.talk = Callable()
		t.mark("")
		_run(true)


func _run(resumed: bool) -> void:
	if _stage() == ARRIVE:
		await _arrive()
	elif resumed:
		Game.cutscene = true
		_freeze(_player())
		_trainer().held = true
		await _say(_who(), ["There you are. We're not finished yet."])
	if _stage() < DUEL:
		await _to_the_dummy()
	for lesson in [ATTACK, PARRY, DODGE]:
		if _stage() == lesson:
			await _lesson(lesson)
	if _stage() == DUEL:
		await _duel()


# --------------------------------------------------------------------------
# 1. Arrival: the sword
# --------------------------------------------------------------------------

func _arrive() -> void:
	Game.cutscene = true
	var clock_was: bool = Game.clock_running
	Game.clock_running = false
	var p := _player()
	var t := _trainer()
	var me: String = Game.player_name
	_freeze(p)
	await _fade(1.0, 0.4)  # (already black when the march brought him here)
	t.held = true
	_put(p, "PlayerArrive", "nw")
	_put(t, "Trainer", "se")
	_look(p, t)
	_look(t, p)
	(p.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _wait(0.4)
	await _fade(0.0, 0.8)
	await _wait(0.5)

	await _say(_who(), ["So you're the one the summoner brought in from the village."])
	await _say(me, ["Yes, sir. I was told to report to the trainer."])
	await _say(_who(), [
		"Then you've found him. Let me see your hands... Good for a plough. Not for a blade.",
		"Not yet, anyway. Here. Take this.",
	])
	await _say("", ["The trainer hands you a sword."])

	# a blink, and the village boy stands there as a soldier
	await _fade(1.0, 0.3)
	p = get_parent().swap_player("mc_warrior")
	_freeze(p)
	_look(p, t)
	await _wait(0.3)
	await _fade(0.0, 0.4)
	_puff(p.global_position)
	await _wait(0.6)
	await _say(me, ["It's heavier than it looks."])
	await _say(_who(), [
		"It will feel lighter by the time I'm done with you. Or you'll be stronger. Either way.",
		"A sword is no use to a man who doesn't know what to do with it.",
		"See that dummy? It has taken more beatings than any soldier in this army. Come.",
	])
	Game.quests.start(QUEST, QUEST_TITLE, PackedStringArray(OBJECTIVES), _who())
	Game.flags[STAGE] = ATTACK
	Game.clock_running = clock_was


## The trainer and the player walk over to the dummy (the player is frozen until a lesson starts).
func _to_the_dummy() -> void:
	var p := _player()
	var t := _trainer()
	Game.cutscene = true
	_freeze(p)
	t.held = true
	await _walk_all([[t, _at("TrainerWatch")], [p, _at("PlayerLesson")]])
	_look(p, _dummy())
	_look(t, p)
	await _wait(0.3)


# --------------------------------------------------------------------------
# 2. Lessons at the dummy
# --------------------------------------------------------------------------

func _lesson(kind: int) -> void:
	var p := _player()
	var t := _trainer()
	var d := _dummy()
	Game.cutscene = true
	_freeze(p)
	t.held = true
	t.watching = false
	_look(t, p)
	match kind:
		ATTACK:
			await _say(_who(), [
				"Left click to attack. Go on, strike the dummy.",
				"Click again as your blade comes back and the cuts follow one another: three in a row, the last one the heaviest.",
			])
		PARRY:
			await _say(_who(), [
				"Good. Now it's the dummy's turn.",
				"I'll set its arm turning. When it winds back, it's about to swing at you.",
				"Right click to parry. Catch the blow just as it lands and it's knocked aside, and your blade answers on its own.",
			])
			d.swinging = true
		DODGE:
			await _say(_who(), [
				"Some blows you can't stop. Then don't be where they land.",
				"Hold a direction and press Space while you move: you're gone before the blow arrives.",
			])
	_count = 0
	_need = LESSONS[kind][1]
	_card_show(LESSONS[kind][0])
	match kind:
		ATTACK:
			d.struck.connect(_on_struck)
		PARRY:
			p.parried.connect(_on_parried)
			p.health_changed.connect(_on_hurt)
			d.swung.connect(_on_swung)
		DODGE:
			p.dodged.connect(_on_dodged)
	t.watching = true
	p.set_physics_process(true)
	Game.cutscene = false

	while _count < _need:
		await _counted

	match kind:
		ATTACK:
			d.struck.disconnect(_on_struck)
		PARRY:
			p.parried.disconnect(_on_parried)
			p.health_changed.disconnect(_on_hurt)
			d.swung.disconnect(_on_swung)
		DODGE:
			p.dodged.disconnect(_on_dodged)
	d.swinging = false
	Game.quests.complete_objective(QUEST, kind - ATTACK)
	Game.flags[STAGE] = kind + 1
	_card_done()
	await _wait(1.0)


func _tick() -> void:
	_count += 1
	_card_count.text = "%d / %d" % [mini(_count, _need), _need]
	var tw := create_tween()
	tw.tween_property(_card_count, "modulate", Color(1.6, 1.4, 0.8), 0.05)
	tw.tween_property(_card_count, "modulate", Color.WHITE, 0.3)
	if _count == ceili(_need / 2.0):
		_trainer().say("Good. Keep going.")
	_counted.emit()


func _on_struck(_amount: int) -> void:
	_tick()


func _on_parried(perfect: bool) -> void:
	_parried_now = true
	_trainer().say("Perfect! That's the moment." if perfect else "Late, but you caught it.")
	_tick()


func _on_hurt(_current: int, _maximum: int) -> void:
	_hurt_now = true


## The arm came round at him: hit without a parry means he was too slow.
func _on_swung() -> void:
	if _hurt_now and not _parried_now:
		_trainer().say("Too slow! Right click as the arm comes round.")
	_hurt_now = false
	_parried_now = false


func _on_dodged(moving: bool) -> void:
	if moving:
		_tick()
	else:
		_trainer().say("Move! Hold a direction as you press Space.")


# --------------------------------------------------------------------------
# 3. The spar
# --------------------------------------------------------------------------

func _duel() -> void:
	var p := _player()
	var t := _trainer()
	var hud = get_parent().hud
	var me: String = Game.player_name
	Game.cutscene = true
	_freeze(p)
	t.held = true
	t.watching = false
	_look(t, p)
	_look(p, t)
	await _say(_who(), [
		"Strike, parry, dodge. That is all a dummy can teach you.",
		"The rest you learn against a man who means it. Fight me.",
		"Don't hold back, %s. I won't." % me,
	])
	await _walk_all([[t, _at("DuelTrainer")], [p, _at("DuelPlayer")]])
	_look(p, t)
	_look(t, p)
	p.heal_full()
	await _wait(0.5)
	hud.show_banner("FIGHT!", Color(1, 0.85, 0.45), 0.6)
	await _wait(0.6)
	t.held = false
	_dummy().remove_from_group("enemy")  # his blade goes for the trainer, not the dummy
	t.start_spar((_at("DuelTrainer") + _at("DuelPlayer")) * 0.5)
	hud.show_foe(t)
	p.set_physics_process(true)
	Game.cutscene = false

	# until one of them is near death
	var beaten := false
	while true:
		await get_tree().physics_frame
		if t.health <= t.max_health * NEAR_DEATH:
			beaten = true
			break
		if p.health <= p.max_health * NEAR_DEATH:
			break

	t.stop_spar()
	hud.hide_foe()
	Game.cutscene = true
	_freeze(p)
	t.held = true
	_look(t, p)
	_look(p, t)
	await _wait(0.6)
	if beaten:
		await _say(_who(), [
			"Enough! Enough...",
			"Ha. Your first day with a sword, and you have your teacher out of breath.",
		])
	else:
		await _say(_who(), [
			"Enough. Lower your blade.",
			"You're hurt and you're tired, and you kept your feet anyway. That is what a battle asks of a man.",
		])
	await _say(me, ["Then... did I pass?"])
	await _say(_who(), [
		"%s. You are ready to fight in the King's battles." % me,
		"Rest while you can. When the army marches, you march with it.",
	])
	p.heal_full()
	Game.quests.complete_objective(QUEST, 3)
	Game.quests.finish(QUEST)
	Game.flags[STAGE] = DONE
	_dummy().add_to_group("enemy")
	t.return_to(_at("Trainer"))  # back to drilling at his post
	p.set_physics_process(true)
	Game.cutscene = false


# --------------------------------------------------------------------------
# The lesson card (top of the screen)
# --------------------------------------------------------------------------

func _card_show(text: String) -> void:
	if _card == null:
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		var top := CenterContainer.new()
		top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		top.offset_top = 66
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(top)
		_card = PanelContainer.new()
		_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.06, 0.1, 0.72)
		sb.border_color = Color(0.85, 0.66, 0.36)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		_card.add_theme_stylebox_override("panel", sb)
		top.add_child(_card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_card.add_child(row)
		_card_text = _card_label(Color(1, 0.93, 0.82))
		_card_count = _card_label(Lacquer.GOLD_TEXT)
		row.add_child(_card_text)
		row.add_child(_card_count)
	_card_text.text = text
	_card_count.text = "0 / %d" % _need
	_card.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.3)


## The lesson is done: the card glows and fades away.
func _card_done() -> void:
	var tw := create_tween()
	tw.tween_property(_card, "modulate", Color(1.5, 1.4, 0.9, 1), 0.15)
	tw.tween_interval(0.6)
	tw.tween_property(_card, "modulate:a", 0.0, 0.4)


func _card_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Lacquer.INK)
	l.add_theme_constant_override("outline_size", 6)
	return l
