extends Node2D
## Ripple rings on the water: around anyone wading (fast while moving, slow while
## standing), around boats, and now and then a fish ring. Drawn only on water.

@export var ring_color := Color(0.86, 0.95, 1.0, 0.75)
@export var max_radius := 26.0
@export var life := 1.6
## Rings are squashed to look flat on the ground (top-down/isometric).
@export var flatten := 0.45
@export var fish_rings := true

var _rings: Array = []        # [pos: Vector2, age: float, life: float, radius: float]
var _last: Dictionary = {}    # body -> [last position, timer]
var _fish := 1.0


func _ready() -> void:
	z_as_relative = false
	z_index = -9
	var m := ShaderMaterial.new()
	m.shader = preload("res://environment/fx/water_mask.gdshader")
	material = m


func add_ring(p: Vector2, radius: float = -1.0, duration: float = -1.0) -> void:
	_rings.append([p, 0.0, life if duration < 0.0 else duration, max_radius if radius < 0.0 else radius])


func _process(delta: float) -> void:
	var bodies: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("actor") \
			+ get_tree().get_nodes_in_group("boss")
	for b in bodies:
		var p: Vector2 = b.global_position
		var st: Array = _last.get(b, [p, 0.0])
		var moving := p.distance_to(st[0]) > 0.4
		st[1] -= delta
		if Game.is_water(p) and st[1] <= 0.0:
			add_ring(p, max_radius * (1.0 if moving else 0.7))
			st[1] = 0.28 if moving else 1.3
		st[0] = p
		_last[b] = st
	for boat in get_tree().get_nodes_in_group("boat"):
		var bst: Array = _last.get(boat, [Vector2.ZERO, randf()])
		bst[1] -= delta
		if bst[1] <= 0.0:
			add_ring(boat.global_position + Vector2(randf_range(-14, 14), 12), max_radius * 1.3, life * 1.3)
			bst[1] = 0.8
		_last[boat] = bst
	if fish_rings and Game.water_image != null:
		_fish -= delta
		if _fish <= 0.0:
			_fish = randf_range(0.6, 1.8)
			var cam := get_viewport().get_camera_2d()
			var c := cam.get_screen_center_position() if cam else Vector2(1000, 640)
			var p := c + Vector2(randf_range(-500, 500), randf_range(-300, 300))
			if Game.water_depth(p) > 0.15:
				add_ring(p, randf_range(8, 16), 1.4)
				add_ring(p, randf_range(4, 8), 1.0)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i][1] += delta
		if _rings[i][1] >= _rings[i][2]:
			_rings.remove_at(i)
	# forget bodies that left
	for k in _last.keys():
		if not is_instance_valid(k):
			_last.erase(k)
	queue_redraw()


func _draw() -> void:
	# in ASCII mode rings are drawn thicker and bigger so they turn into ( ) / \ text rings
	var w := 2.0 if Game.ascii_mode else 1.0
	var big := 1.5 if Game.ascii_mode else 1.0
	for r in _rings:
		var t: float = r[1] / r[2]
		var e := 1.0 - pow(1.0 - t, 2.0)                  # ease out
		var a := pow(1.0 - t, 1.4) * ring_color.a
		var col := Color(ring_color, a)
		draw_set_transform(r[0], 0.0, Vector2(1.0, flatten))
		draw_arc(Vector2.ZERO, 1.5 + e * r[3] * big, 0.0, TAU, 36, col, w, false)
		if t > 0.12:                                       # second, inner ring
			var e2 := 1.0 - pow(1.0 - (t - 0.12) / 0.88, 2.0)
			draw_arc(Vector2.ZERO, 1.0 + e2 * r[3] * 0.62 * big, 0.0, TAU, 28, Color(col, a * 0.6), w, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
