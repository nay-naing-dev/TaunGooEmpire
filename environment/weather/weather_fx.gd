extends Node2D
## Drawing helper for the weather: rain splashes and scorch marks on the ground,
## or (bolts_mode) the lightning bolts in the sky.

var bolts_mode := false
var _splashes: Array = []      # [pos, age]
var _scorch: Array = []        # [pos, age]
var _bolts: Array = []         # [polylines, age]


func _ready() -> void:
	if bolts_mode:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m


func splash(p: Vector2) -> void:
	if _splashes.size() < 260:
		_splashes.append([p, 0.0, randf() * TAU])


func scorch(p: Vector2) -> void:
	_scorch.append([p, 0.0])


func bolt(target: Vector2, top_y: float) -> void:
	var start := Vector2(target.x + randf_range(-90, 90), top_y)
	var main := _jag(start, target, 7, 0.28)
	var lines: Array = [[main, 1.0]]
	for i in randi_range(2, 4):
		var j := randi_range(int(main.size() * 0.2), int(main.size() * 0.75))
		var from: Vector2 = main[j]
		var dir := (target - start).normalized().rotated(randf_range(0.4, 0.9) * (1 if randf() < 0.5 else -1))
		var to := from + dir * (target - from).length() * randf_range(0.3, 0.55)
		var br := _jag(from, to, 5, 0.3)
		lines.append([br, 0.45])
		if randf() < 0.5:
			var k := randi_range(1, br.size() - 2)
			var d2 := dir.rotated(randf_range(-0.7, 0.7))
			lines.append([_jag(br[k], br[k] + d2 * randf_range(20, 50), 3, 0.3), 0.25])
	_bolts.append([lines, 0.0])


func _jag(a: Vector2, b: Vector2, depth: int, rough: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	for d in depth:
		var np := PackedVector2Array()
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var m := (p0 + p1) / 2.0
			var n := (p1 - p0).orthogonal().normalized()
			m += n * randf_range(-1.0, 1.0) * (p1 - p0).length() * rough
			np.append(p0)
			np.append(m)
		np.append(pts[pts.size() - 1])
		pts = np
	return pts


func _process(delta: float) -> void:
	for a in [_splashes, _scorch, _bolts]:
		for e in a:
			e[1] += delta
	_splashes = _splashes.filter(func(e): return e[1] < 0.32)
	_scorch = _scorch.filter(func(e): return e[1] < 6.0)
	_bolts = _bolts.filter(func(e): return e[1] < 0.42)
	queue_redraw()


func _draw() -> void:
	if bolts_mode:
		for b in _bolts:
			var t: float = b[1]
			# three pulses, then gone
			var a := 1.0 if t < 0.06 else (0.25 if t < 0.12 else (1.0 if t < 0.18 else (1.0 - (t - 0.18) / 0.24)))
			for l in b[0]:
				var pts: PackedVector2Array = l[0]
				var s: float = l[1]
				draw_polyline(pts, Color(0.45, 0.55, 1.0, 0.12 * a * s), 22.0 * s, true)
				draw_polyline(pts, Color(0.55, 0.65, 1.0, 0.25 * a * s), 10.0 * s, true)
				draw_polyline(pts, Color(0.75, 0.82, 1.0, 0.5 * a * s), 4.5 * s, true)
				draw_polyline(pts, Color(1.0, 1.0, 1.0, a * (0.7 + 0.3 * s)), maxf(1.0, 2.4 * s), true)
		return
	for s in _scorch:
		var u: float = s[1] / 6.0
		draw_set_transform(s[0], 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 14.0, Color(0.05, 0.04, 0.03, 0.55 * (1.0 - u)))
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.55, 0.2, maxf(0.0, 0.9 - u * 6.0)))
	for s in _splashes:
		var t: float = s[1] / 0.32
		var p: Vector2 = s[0]
		var a := (1.0 - t) * 0.6
		draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 1.0 + 5.0 * t, 0.0, TAU, 12, Color(0.82, 0.88, 1.0, a), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in 3:
			var ang: float = s[2] + k * 2.1
			var d := Vector2(cos(ang) * 4.0 * t, -9.0 * t + 14.0 * t * t)
			draw_rect(Rect2(p + d, Vector2(1, 1)), Color(0.85, 0.9, 1.0, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
