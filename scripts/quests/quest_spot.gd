extends Node2D
class_name QuestSpot
## Something in the world a quest wants looked at or talked to: an "E" shows over it
## when the player is close, E calls `used`. Made in code by the story scene.

const SpeechBubble := preload("res://scripts/speech_bubble.gd")

var used := Callable()
## Ground distance (up / down counts double) the player can use it from.
var reach := 42.0
var _bubble: SpeechBubble


func _init(height := 40.0) -> void:
	_bubble = SpeechBubble.new()
	_bubble.head_height = height


func _ready() -> void:
	add_to_group("interactable")
	add_child(_bubble)


func can_interact(who: Node2D) -> bool:
	return used.is_valid() and not Game.in_dialogue() \
			and Vector2(who.global_position.x - global_position.x, (who.global_position.y - global_position.y) * 2.0).length() < reach


func interact(_who: Node2D) -> void:
	used.call()


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_bubble.hint(p != null and can_interact(p))
