extends Node2D
## Where a delivery quest ends (put it on the building, e.g. the animal shed).
## While Game.flags[quest] is "active" and the bag has the item, an "E" shows when
## the player is in reach; press it and the item leaves the bag, the quest is "done"
## and "Quest Complete!" pops up over the player's head.

## The quest's key in Game.flags (the quest giver sets it to "active").
@export var quest := ""
## Item id taken from the bag (res://items/<id>.tres).
@export var item_id := ""
@export var count := 1
## How close the player must be (ground distance, up / down counts double like the villagers).
@export var reach := 120.0
## How far above this node the "E" sits.
@export var hint_height := 40.0
## How far above the player's feet "Quest Complete!" shows.
@export var player_head_height := 72.0

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
	return Game.flags.get(quest, "") == "active" and Game.inventory.has_id(item_id, count) \
			and not Game.in_dialogue() and _near(who)


func interact(who: Node2D) -> void:
	if not Game.inventory.remove_id(item_id, count):
		return
	Game.flags[quest] = "done"
	var pop := who.get_node_or_null("QuestBubble") as SpeechBubble
	if pop == null:
		pop = SpeechBubble.new()
		pop.name = "QuestBubble"
		pop.tail = SpeechBubble.Tail.NONE
		pop.head_height = player_head_height
		pop.font_size = 18
		who.add_child(pop)
	pop.say("Quest Complete!", 3.0)


func _process(_delta: float) -> void:
	_bubble.hint(can_interact(get_tree().get_first_node_in_group("player") as Node2D))
