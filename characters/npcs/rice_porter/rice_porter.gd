extends "res://characters/npcs/villager.gd"
## The rice porter, giver of the first quest: his back hurts from plowing, so he
## asks you to take a haystack to the animal shed (the DeliverySpot on the shed
## finishes it). A "!" floats over his head until you take the chore.
## The first talk is in the dialogue box and puts the haystack in your bag.
## While you carry it he reminds you where to go; after that he says his Lines.

## His name in the dialogue box.
@export var display_name := "Rice Porter"

## Game.flags[QUEST]: missing = not asked yet, "active" = haystack on the way, "done".
const QUEST := "haystack_quest"
const ITEM := "haystack"
const ASK := [
	"Morning {player}! Care for a little chore?",
	"I have to carry haystacks to the animal shed for animal food! But my back hurt from plowing all day. Can you deliver this haystack to the shed?",
]
const REMINDER := "The animal shed is down south, past the big jars. Thank you, {player}!"
const BAG_FULL := "Your bag is full, {player}. Make some room and come back."


func _ready() -> void:
	super()
	if _bubble and not Game.flags.has(QUEST):
		_bubble.mark("!")


func interact(who: Node2D) -> void:
	var state: String = Game.flags.get(QUEST, "")
	if state == "done":
		super(who)
		return
	_face(who.global_position - global_position)
	if state == "active":
		_bubble.say(REMINDER.format({"player": Game.player_name}))
		return
	var lines := PackedStringArray()
	for l in ASK:
		lines.append(l.format({"player": Game.player_name}))
	Game.dialogue(display_name, lines, _give_haystack)


func _give_haystack() -> void:
	if Game.inventory.add_id(ITEM) > 0:
		_bubble.say(BAG_FULL.format({"player": Game.player_name}))
		return
	Game.flags[QUEST] = "active"
	_bubble.mark("")
