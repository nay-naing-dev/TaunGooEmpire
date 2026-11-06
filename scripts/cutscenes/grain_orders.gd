extends Cutscene
## The palace half of the grain quests (the forest half is grain_quest.gd).
## - Right after the spar (training_day.gd) the Quartermaster comes to the trainer:
##   the supply cart is broken and rice has to cross the river. The trainer hands the job
##   to the player, who gets a rice bag to carry; quest "Grain for the March" starts.
## - When the player is back with the bag the trainer has a "?" over him: talk to him
##   (E). What he says depends on what the player did with Nga Tay; that finishes
##   quest "The Price of Grain".
## The Marker2D children are where everyone stands; move them in the editor.

const QUARTERMASTER := "Quartermaster"
const QUARTERMASTER_SCENE := "res://characters/palace/spear_guard/spear_guard.tscn"

@export var trainer_path: NodePath = ^"../Objects/Trainer1"
@export var post_path: NodePath = ^"../TrainingDay/Trainer"

var _running := false


func _process(_delta: float) -> void:
	if _running or not Game.flags.has(GrainQuest.STAGE):
		return
	var stage: int = Game.flags[GrainQuest.STAGE]
	if stage != GrainQuest.ORDERS and stage != GrainQuest.RETURN:
		return
	if get_tree().paused or Game.in_dialogue() or _player() == null:
		return
	_running = true
	if stage == GrainQuest.ORDERS:
		_orders()
	else:
		_wait_for_report()


func _trainer() -> Node2D:
	return get_node(trainer_path) as Node2D


func _who() -> String:
	return _trainer().display_name


func _orders() -> void:
	Game.cutscene = true
	var clock_was: bool = Game.clock_running
	Game.clock_running = false
	var p := _player()
	var t := _trainer()
	_freeze(p)
	t.held = true
	await _walk_all([[t, _at("Trainer")], [p, _at("Player")]])
	_look(t, p)
	_look(p, t)
	await _wait(0.6)

	var q := _spawn("QuartermasterStart", QUARTERMASTER_SCENE, "sw")
	await _walk_all([[q, _at(QUARTERMASTER)]])
	_look(q, t)
	_look(t, q)
	_look(p, q)
	await _say(QUARTERMASTER, [
		"The rice for the army has to cross the river today, and the supply cart has broken down.",
		"Without rice, these soldiers don't march.",
	])
	_look(t, p)
	_look(p, t)
	await _ask(_who(), [
		"You've finished your training, so try some real work.",
		"Take a bag of rice and carry it along the forest road, over the river.",
	], [
		"As you order. I'll go.",
		"Is the road safe?",
	])
	await _say(_who(), [
		"We don't know yet. There have been outlaws in that forest.",
		"Keep your eyes open. And don't start a fight you can't finish.",
	])
	await _say("", ["The Quartermaster hands you a heavy bag of rice. With that on your shoulder you can only walk."])
	p.set_carrying(true)

	Game.quests.start(GrainQuest.QUEST, GrainQuest.QUEST_TITLE, PackedStringArray(GrainQuest.OBJECTIVES), _who())
	Game.quests.complete_objective(GrainQuest.QUEST, 0)
	Game.flags[GrainQuest.STAGE] = GrainQuest.CARRY
	Game.clock_running = clock_was
	p.set_physics_process(true)
	Game.cutscene = false
	t.return_to(get_node(post_path).global_position)  # back to drilling at his post
	_running = false
	await _walk_all([[q, _at("QuartermasterStart")]])
	q.queue_free()


func _wait_for_report() -> void:
	var t := _trainer()
	t.mark("?")
	t.talk = func():
		t.talk = Callable()
		t.mark("")
		_report()


func _report() -> void:
	var p := _player()
	var t := _trainer()
	Game.cutscene = true
	_freeze(p)
	t.held = true
	_look(t, p)
	_look(p, t)
	var me: String = Game.player_name
	await _say(me, ["Outlaws jumped me at the river, sir. Nga Tay and five of his men. I brought the rice back."])
	p.set_carrying(false)
	match String(Game.flags.get(GrainQuest.FATE, "")):
		"bound":
			await _say(_who(), [
				"And their leader is bound for judgement. Good.",
				"That was the harder road. Most men would have taken the easier one, either way.",
			])
		"released":
			await _say(_who(), [
				"You let him go? Hm. You showed mercy, and you'll answer for it if he robs us again.",
				"Mercy isn't weakness, %s. But it isn't free." % me,
			])
		_:
			await _say(_who(), [
				"So he is dead. I can see it on you.",
				"You'll carry that one. Everyone does. Sit down before you fall down.",
			])
	await _say(_who(), ["The men will eat, and the army can march. Get some rest."])
	Game.quests.complete_objective(GrainQuest.QUEST_CAMP, GrainQuest.OBJECTIVES_CAMP.size() - 1)
	Game.quests.finish(GrainQuest.QUEST_CAMP)
	Game.flags[GrainQuest.STAGE] = GrainQuest.DONE
	t.held = false
	p.set_physics_process(true)
	Game.cutscene = false
	_running = false
