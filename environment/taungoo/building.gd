extends StaticBody2D
## Isometric Taungoo building or prop the player can walk around.
## - Draws the player in front of or behind it using the real front edges
##   (plain Y-sorting gets isometric buildings wrong near the sides).
## - Works when several buildings overlap: all buildings are checked together.
## - Turns see-through when the player is hidden behind it.

## The building's front edges at ground level, left to right, in local pixels.
## The node origin is the front-most corner.
@export var front_edge: PackedVector2Array = PackedVector2Array([Vector2(-135, -61), Vector2(0, 0), Vector2(65, -39)])
@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.45
@export var fade_speed: float = 4.0

@onready var _sprite: Sprite2D = $Sprite2D

static var _resolved_frame := -1


func _ready() -> void:
	add_to_group("building")


func _edge_y(x: float) -> float:
	for i in front_edge.size() - 1:
		var a := front_edge[i]
		var b := front_edge[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return 0.0


## 1 = body is behind this building, -1 = in front of it, 0 = not overlapping the picture.
func relation(body: Node2D) -> int:
	var local := to_local(body.global_position)
	var rect := _sprite.get_rect()
	if not rect.has_point(local):
		return 0
	var over_us := local.x >= front_edge[0].x and local.x <= front_edge[front_edge.size() - 1].x
	var in_front := (not over_us) or local.y >= _edge_y(local.x)
	return -1 if in_front else 1


func _process(delta: float) -> void:
	var target := 1.0
	for p in get_tree().get_nodes_in_group("player"):
		if relation(p) == 1:
			target = faded_alpha
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, delta * fade_speed)
	var f := Engine.get_process_frames()
	if f != _resolved_frame:
		_resolved_frame = f
		_resolve()


## One pass for all buildings: a body in front of a building (but higher up on
## screen than its origin) is raised; a building the raised body is behind is
## raised above it.
func _resolve() -> void:
	var buildings := get_tree().get_nodes_in_group("building")
	for b in buildings:
		b.z_index = 0
	for body in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("actor"):
		# inside a house / palace room (house.gd lifts the player to z 41): leave it alone
		if body.z_index >= 40 or (body.is_in_group("player") and Game.get("indoors") == true):
			continue
		var raise := false
		var behind: Array = []
		for b in buildings:
			var r: int = b.relation(body)
			if r == -1 and body.global_position.y < b.global_position.y:
				raise = true
			elif r == 1:
				behind.append(b)
		body.z_index = 1 if raise else 0
		if raise:
			for b in behind:
				b.z_index = 2
