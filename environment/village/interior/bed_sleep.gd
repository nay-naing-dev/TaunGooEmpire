extends Node2D
## A bed you can sleep in (put it on the bed, at the middle of the mattress).
## Standing next to it inside the house an "E" shows; press E:
## - at night (from BEDTIME until WAKE_HOUR): "Sleep through the night?" Yes / No.
##   Yes: the screen fades to black, the clock jumps to WAKE_HOUR (the next day when
##   it was still evening) and the morning fades in.
## - by day: "You can only sleep at night!"

const BEDTIME := 18.0
const WAKE_HOUR := 6.0
const SpeechBubble := preload("res://scripts/speech_bubble.gd")

## How close the player must be (ground distance, up / down counts double).
@export var reach := 72.0
## How far above this node the "E" sits.
@export var hint_height := 34.0
var _bubble: SpeechBubble


func _ready() -> void:
	add_to_group("interactable")
	_bubble = SpeechBubble.new()
	_bubble.tail = SpeechBubble.Tail.NONE
	_bubble.head_height = hint_height
	add_child(_bubble)


func _near(p: Node2D) -> bool:
	return p != null and Vector2(p.global_position.x - global_position.x, (p.global_position.y - global_position.y) * 2.0).length() < reach


## Only inside the house (the room is hidden from outside).
func can_interact(who: Node2D) -> bool:
	return is_visible_in_tree() and not Game.in_dialogue() and not get_tree().paused and _near(who)


func _process(_delta: float) -> void:
	_bubble.hint(can_interact(get_tree().get_first_node_in_group("player") as Node2D))


func interact(_who: Node2D) -> void:
	if Game.hour >= BEDTIME or Game.hour < WAKE_HOUR:
		Game.prompt("Sleep through the night?", PackedStringArray(["Yes", "No"]), func(i: int):
			if i == 0:
				_sleep())
	else:
		Game.prompt("You can only sleep at night!")


## Black screen while the night passes; the world stays paused until the morning is in.
func _sleep() -> void:
	var tree := get_tree()
	tree.paused = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(black)
	Game.add_child(layer)
	var t := black.create_tween()
	t.tween_property(black, "color:a", 1.0, 0.7)
	await t.finished
	var day: int = Game.day + (1 if Game.hour >= 12.0 else 0)  # slept past midnight
	Game.set_hour(WAKE_HOUR)
	Game.day = day
	# light the morning now (lamps out, sun up) while nothing else moves
	var world := tree.current_scene
	if world and world.has_method("apply_time"):
		world.apply_time(Game.time_of_day, false)
	tree.call_group("night_lamp", "snap")
	await tree.create_timer(1.2, true).timeout
	t = black.create_tween()
	t.tween_property(black, "color:a", 0.0, 0.9)
	await t.finished
	layer.queue_free()
	tree.paused = false
