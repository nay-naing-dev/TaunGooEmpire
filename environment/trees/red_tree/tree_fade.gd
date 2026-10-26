extends Area2D
## Put this on an Area2D inside red_tree.tscn.
## When the player walks BEHIND the tree (above its trunk on screen),
## the tree fades so the player can still be seen through the leaves.

## How see-through the tree gets (0 = invisible, 1 = solid).
@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.45
## Seconds to fade in / out.
@export var fade_time: float = 0.25

var _bodies: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	var tree_sprite := get_parent().get_node_or_null("Tree") as CanvasItem
	if tree_sprite == null:
		return

	var trunk_y: float = (get_parent() as Node2D).global_position.y
	var someone_behind := false
	for body in _bodies:
		# Smaller y = higher on screen = behind the trunk.
		if is_instance_valid(body) and body.global_position.y < trunk_y:
			someone_behind = true
			break

	var target := faded_alpha if someone_behind else 1.0
	var a := move_toward(tree_sprite.modulate.a, target, delta / max(fade_time, 0.01))
	tree_sprite.modulate.a = a


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
