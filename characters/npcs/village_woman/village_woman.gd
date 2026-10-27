extends "res://characters/npcs/villager.gd"
## The woman by the animal shed. A trader told her the royal summoner is coming.
## A "?" floats over her head until you have talked to her. The first talk is a
## conversation in the dialogue box: she tells the news, then you can ask her
## about it (each answer brings the questions back) until you thank her.
## After that she says her Lines over her head like any villager.

## Her name in the dialogue box.
@export var display_name := "Village Woman"

const HEARD := "village_woman_news_heard"
const INTRO := [
	"Good morning {player}! Have you heard the news?",
	"I heard it from a trader who came through yesterday. He said the king has been calling men from villages all across the kingdom. The summoner will come around 2 days from now.",
	"I wonder what His Majesty needs so many men for. Surely, it cannot be for something peaceful.",
]
const CHOICES := [
	"What have you heard?",
	"Why would King need more men?",
	"Are you worried?",
	"I see. Thank you for telling me.",
]
## What she says to each choice (the last choice ends the talk).
const ANSWERS := [
	[
		"Well, the trader said there had been talk of another campaign. He claimed that soldiers were gathering near the royal city.",
		"But traders have a habit of making their stories bigger with every village they visit. Perhaps there's truth in it, perhaps not.",
	],
	[
		"Who can say? A king must protect his lands, contend with his rivals, and keep his enemies at bay.",
		"Still, whenever the great men quarrel, it is often the farmers who pay the price.",
	],
	[
		"I have a husband and two sons. The youngest is barely old enough to carry a spear.",
		"I can bear a little hardship. But the thought of seeing my children marched away to some distant land... that is another matter.",
	],
]


func _ready() -> void:
	super()
	if _bubble and not Game.flags.get(HEARD, false):
		_bubble.mark("?")


func interact(who: Node2D) -> void:
	if Game.flags.get(HEARD, false):
		super(who)
		return
	_face(who.global_position - global_position)
	_bubble.mark("")
	Game.dialogue(display_name, _fill(INTRO), _on_choice, PackedStringArray(CHOICES))


func _on_choice(i: int) -> void:
	Game.flags[HEARD] = true
	if i < ANSWERS.size():
		Game.dialogue(display_name, _fill(ANSWERS[i]), _on_choice, PackedStringArray(CHOICES))


func _fill(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		out.append(l.format({"player": Game.player_name}))
	return out
