extends Control
## Title screen over the living royal palace.

@onready var td_pick: OptionButton = %TopdownPick


func _ready() -> void:
	for key in Game.TOPDOWN.keys():
		td_pick.add_item(key.capitalize())
	td_pick.select(Game.TOPDOWN.keys().find(Game.topdown_character))
	%ExploreButton.pressed.connect(_on_explore)
	%ExploreButton.grab_focus()
	var tw := create_tween().set_loops()
	tw.tween_property(%Hint, "modulate:a", 0.35, 1.2)
	tw.tween_property(%Hint, "modulate:a", 1.0, 1.2)


func _on_explore() -> void:
	Game.topdown_character = Game.TOPDOWN.keys()[td_pick.selected]
	Game.go(Game.VILLAGE)
