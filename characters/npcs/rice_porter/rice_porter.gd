extends "res://characters/npcs/villager.gd"
## The rice porter, giver of the first quest ("A Little Chore"): his back hurts from
## plowing, so he asks you to take a haystack to the animal shed (the DeliverySpot
## on the shed ticks it off). A "!" floats over his head until you take the chore,
## a "?" once it is done and he has your reward.
## - First talk (dialogue box): he asks, the haystack goes in your bag, the quest starts.
## - While you carry it: he reminds you where to go.
## - Quest completed: he thanks you and gives 3 Mont Phet Htoke (if they fit in the bag).
## - After that he says his Lines.

## His name in the dialogue box (and in "Return to the ... for your reward").
@export var display_name := "Rice Porter"

const QUEST := "haystack_quest"
const QUEST_TITLE := "A Little Chore"
const OBJECTIVES := ["Deliver Haystack"]
const ITEM := "haystack"
const REWARD := "mont_phet_htoke"
const REWARD_COUNT := 3
const ASK := [
	"Morning {player}! Care for a little chore?",
	"I have to carry haystacks to the animal shed for animal food! But my back hurt from plowing all day. Can you deliver this haystack to the shed?",
]
const REMINDER := "The animal shed is down south, past the big jars. Thank you, {player}!"
const THANKS := [
	"You took it to the shed already? Bless you, {player}. My back thanks you.",
	"My wife steamed some Mont Phet Htoke this morning. Here, take three. They'll keep your strength up.",
]
const BAG_FULL := "Your bag is full, {player}. Make some room and come back."


func _ready() -> void:
	super()
	if _bubble:
		Game.quests.changed.connect(_update_mark)
		_update_mark()


func _exit_tree() -> void:
	if Game.quests.changed.is_connected(_update_mark):
		Game.quests.changed.disconnect(_update_mark)


func _update_mark() -> void:
	if not Game.quests.has(QUEST):
		_bubble.mark("!")
	elif Game.quests.is_completed(QUEST):
		_bubble.mark("?")
	else:
		_bubble.mark("")


func interact(who: Node2D) -> void:
	if Game.quests.is_finished(QUEST):
		super(who)
		return
	_face(who.global_position - global_position)
	if Game.quests.is_active(QUEST):
		_bubble.say(_fill([REMINDER])[0])
	elif Game.quests.is_completed(QUEST):
		Game.dialogue(display_name, _fill(THANKS), _give_reward)
	else:
		Game.dialogue(display_name, _fill(ASK), _give_haystack)


func _give_haystack() -> void:
	if Game.inventory.add_id(ITEM) > 0:
		_bubble.say(_fill([BAG_FULL])[0])
		return
	Game.quests.start(QUEST, QUEST_TITLE, PackedStringArray(OBJECTIVES), display_name)


func _give_reward() -> void:
	var food := ItemData.find(REWARD)
	if Game.inventory.space_for(food) < REWARD_COUNT:
		_bubble.say(_fill([BAG_FULL])[0])
		return
	Game.inventory.add(food, REWARD_COUNT)
	Game.quests.finish(QUEST)


func _fill(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		out.append(l.format({"player": Game.player_name}))
	return out
