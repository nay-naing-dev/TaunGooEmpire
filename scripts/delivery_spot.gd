extends Node2D
## Where a delivery objective is done (put it on the building, e.g. the animal shed).
## While the quest is active and the bag has the item, an "E" shows when the player
## is in reach; press it and the item leaves the bag and the objective is ticked off
## in Game.quests (the last one completes the quest: "Quest Completed: <name>").

## The quest's id in Game.quests (the quest giver starts it).
@export var quest := ""
## Which of its objectives this delivery is (0 = the first).
@export var objective := 0
## Item id taken from the bag (res://items/<id>.tres).
@export var item_id := ""
@export var count := 1
## How close the player must be (ground distance, up / down counts double like the villagers).
@export var reach := 120.0
## How far above this node the "E" sits.
@export var hint_height := 40.0

const SpeechBubble := preload("res://scripts/speech_bubble.gd")
var _bubble: SpeechBubble


func _ready() -> void:
	add_to_group("interactable")
	_bubble = SpeechBubble.new()
	_bubble.tail = SpeechBubble.Tail.NONE
	_bubble.head_height = hint_height
	add_child(_bubble)


func _near(p: Node2D) -> bool:
	return p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < reach


func can_interact(who: Node2D) -> bool:
	return Game.quests.is_active(quest) and Game.inventory.has_id(item_id, count) \
			and not Game.in_dialogue() and _near(who)


func interact(_who: Node2D) -> void:
	if Game.inventory.remove_id(item_id, count):
		Game.quests.complete_objective(quest, objective)


func _process(_delta: float) -> void:
	_bubble.hint(can_interact(get_tree().get_first_node_in_group("player") as Node2D))
