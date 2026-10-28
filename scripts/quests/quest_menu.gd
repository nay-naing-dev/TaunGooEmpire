extends CanvasLayer
## Current Quests window: Tab opens / closes it, Esc closes it too. The world pauses
## while it is open. Shows Game.quests: each quest still going gets a black-lacquer
## card with its name and objectives (gold check box, ticked when done); a completed
## one says who to go back to for the reward. Finished quests are listed under them.
## Looks: the Lacquer window, like the inventory (cards in res://ui/quests/).

const CARD_TEX := preload("res://ui/quests/quest_card.png")
const CHECK_TEX := preload("res://ui/quests/check.png")
const CHECK_DONE_TEX := preload("res://ui/quests/check_done.png")
const DONE_TEXT := Color(0.62, 0.92, 0.55)
const WIDTH := 520.0
## How far below the middle of the screen the window sits (same as the inventory).
const DROP := 70.0

var quests: QuestLog
var _root: Control
var _list: VBoxContainer
var _tw: Tween


func _ready() -> void:
	layer = 12  # above the HUD and the dialogue box
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := Lacquer.window(_root, "Current Quests", DROP)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = WIDTH
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	var help := Lacquer.label("Tab / Esc: close", 13, Color(Lacquer.CREAM, 0.75))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	visible = false


func set_quests(quest_log: QuestLog) -> void:
	quests = quest_log
	quests.changed.connect(func():
		if visible:
			_rebuild())


func can_open() -> bool:
	return not visible and not get_tree().paused and not Game.in_dialogue() \
			and get_tree().get_first_node_in_group("player") != null


func open() -> void:
	visible = true
	get_tree().paused = true
	_rebuild()
	_root.modulate.a = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var finished: Array[QuestLog.Quest] = []
	for q in quests.list():
		if q.state == QuestLog.State.FINISHED:
			finished.append(q)
		else:
			_list.add_child(_card(q))
	if _list.get_child_count() == 0:
		var none := Lacquer.label("No quests right now.\nVillagers with a ! over their head could use a hand.", 15, Lacquer.CREAM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)
	if not finished.is_empty():
		_list.add_child(Lacquer.label("Finished", 14, Color(Lacquer.GOLD_TEXT, 0.7)))
		for q in finished:
			_list.add_child(_check_row(q.title, true, Color(Lacquer.CREAM, 0.5)))


## One quest still going: its name, its objectives, and where to claim the reward.
func _card(q: QuestLog.Quest) -> PanelContainer:
	var card := Lacquer.framed(CARD_TEX, 16, 18, 10, 18, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	var title := Lacquer.label(q.title, 18, Lacquer.GOLD_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if q.state == QuestLog.State.COMPLETED:
		head.add_child(Lacquer.label("Completed", 14, DONE_TEXT))
	box.add_child(head)
	for i in q.objectives.size():
		box.add_child(_check_row(q.objectives[i], q.done[i], Color(Lacquer.CREAM, 0.6) if q.done[i] else Lacquer.CREAM))
	if q.state == QuestLog.State.COMPLETED and q.giver != "":
		var back := Lacquer.label("Return to the %s for your reward." % q.giver, 14, DONE_TEXT)
		back.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(back)
	return card


func _check_row(text: String, ticked: bool, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var check := TextureRect.new()
	check.texture = CHECK_DONE_TEX if ticked else CHECK_TEX
	check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(check)
	var l := Lacquer.label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _pressed(event: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _input(event: InputEvent) -> void:
	if quests == null or event.is_echo():
		return
	if not visible:
		if _pressed(event, ["quest_log"]) and can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	get_viewport().set_input_as_handled()  # the paused world gets nothing while it is open
	if _pressed(event, ["quest_log", "ui_cancel"]):
		close()
