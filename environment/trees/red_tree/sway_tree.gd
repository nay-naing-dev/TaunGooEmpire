@tool
extends Node2D
## Chill swaying tree. All the parts are real nodes saved in red_tree.tscn,
## so the tree is always visible in the editor. This script only:
##   - steps the 8 sway frames on the tree, its shadow and its reflection
##   - gives every tree its own random timing so a forest never moves in sync

## Frames per second. 4 = one full sway every 2 seconds (chill).
@export_range(1.0, 12.0, 0.5) var fps: float = 4.0
@export var randomize_phase: bool = true

@onready var _tree: Sprite2D = get_node_or_null("Tree")
@onready var _shadow: Sprite2D = get_node_or_null("Shadow")
@onready var _reflection: Sprite2D = get_node_or_null("Reflection")

var _time := 0.0
var _speed := 1.0


func _ready() -> void:
	if randomize_phase and not Engine.is_editor_hint():
		_speed = randf_range(0.85, 1.15)
		_time = randf_range(0.0, 8.0 / fps)


func _process(delta: float) -> void:
	if _tree == null:
		return
	_time += delta * _speed
	var frame := int(_time * fps) % _tree.hframes
	_tree.frame = frame
	if _shadow:
		_shadow.frame = frame
	if _reflection:
		_reflection.frame = frame
