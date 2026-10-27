extends Area2D
## Walk into this zone and a line of text appears.
## - On Player: the player thinks it (thought bubble over their head) for a while.
##   Shows again after Repeat After seconds once they left and came back (0 = only once).
## - Otherwise: a note shows above this node (put it on the building)
##   and stays up while the player is in the zone.

@export_multiline var text := ""
@export var on_player := false
## How far above the player's feet (On Player) or above this node the text sits.
@export var head_height := 92.0
@export var repeat_after := 60.0

const SpeechBubble := preload("res://scripts/speech_bubble.gd")
var _bubble: SpeechBubble
var _next := 0.0


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if not on_player:
		_bubble = SpeechBubble.new()
		_bubble.tail = SpeechBubble.Tail.NONE
		_bubble.head_height = head_height
		add_child(_bubble)


func _on_enter(b: Node) -> void:
	if not b.is_in_group("player") or text == "":
		return
	if not on_player:
		_bubble.show_text(text)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next:
		return
	_next = now + repeat_after if repeat_after > 0.0 else INF
	var thought := b.get_node_or_null("ThoughtBubble") as SpeechBubble
	if thought == null:
		thought = SpeechBubble.new()
		thought.name = "ThoughtBubble"
		thought.tail = SpeechBubble.Tail.THOUGHT
		thought.head_height = head_height
		b.add_child(thought)
	thought.say(text)


func _on_exit(b: Node) -> void:
	if not on_player and b.is_in_group("player"):
		_bubble.show_text("")
