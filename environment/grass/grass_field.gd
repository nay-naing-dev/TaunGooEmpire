extends Node2D
## Thousands of smooth grass tufts over the world (like 3D grass, not pixel art).
##  - Every leaf is real geometry with soft light-to-dark shading, so each leaf bends
##    on its own: idle sway, wind gusts rolling across the map, fluttering tips.
##  - Grass is pushed aside by you and the boss, is darker under tree shadows,
##    and every tuft casts a soft swaying shadow.
##  - Where grass grows comes from `mask` (grass_mask.png, same shape as the map):
##    white = grass, black = none, grey = sparse. Paint it in any image editor.

@export var mask: Texture2D = preload("res://environment/grass/grass_mask.png")
@export var map_size := Vector2(2048, 1280)
## 1 = about one tuft every 19 pixels. 2 = twice as many.
@export_range(0.1, 4.0, 0.05) var density := 1.0
@export var random_seed := 7
@export var min_scale := 0.7
@export var max_scale := 1.25
@export var cast_shadows := true
## Smooth (anti-aliased) leaf edges. Turns on 4x MSAA for 2D.
@export var smooth_edges := true
## How far around a character the grass is pushed aside (pixels).
@export var bend_radius := 26.0
## The Y-sorted node the grass goes into (same one as trees and characters).
@export var objects_path: NodePath = ^"../Objects"

@export_group("Look")
@export var leaf_light := Color(0.50, 0.78, 0.30)
@export var leaf_dark := Color(0.20, 0.42, 0.16)
@export var leaf_base := Color(0.12, 0.25, 0.10)
@export var tip_dry := Color(0.72, 0.70, 0.36)
@export var variants := 16

@export_group("Wind")
@export var sway := 1.6
@export var gust_lean := 4.0
@export var flutter := 0.8
@export var speed := 1.6

const BAND_HEIGHT := 8.0


## Vertex data for a triangle strip (positions, colours, wind data).
class Buf:
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

	func add(p: Vector2, col: Color, w: Vector2) -> void:
		v.append(p)
		c.append(col)
		uv.append(w)

	## Repeat the first and last vertex so separate leaves can share one strip.
	func join(start: int) -> void:
		v.insert(start, v[start])
		c.insert(start, c[start])
		uv.insert(start, uv[start])
		v.append(v[v.size() - 1])
		c.append(c[c.size() - 1])
		uv.append(uv[uv.size() - 1])

	func add_xf(xf: Transform2D, o: Buf, with_colour := true) -> void:
		v.append_array(xf * o.v)
		if with_colour:
			c.append_array(o.c)
		uv.append_array(o.uv)
var tuft_count := 0
var _mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
var _templates: Array = []


func _ready() -> void:
	if smooth_edges:
		get_viewport().msaa_2d = Viewport.MSAA_4X
	var shader := preload("res://environment/grass/grass.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = shader
	_shadow_mat.set_shader_parameter("is_shadow", true)
	for m in [_mat, _shadow_mat]:
		m.set_shader_parameter("sway", sway)
		m.set_shader_parameter("gust_lean", gust_lean)
		m.set_shader_parameter("flutter", flutter)
		m.set_shader_parameter("speed", speed)
	_plant.call_deferred()


# ------------------------------------------------------------------ leaf shapes

## One leaf as a triangle strip: soft shading across (lit edge -> shaded edge)
## and along (dark base -> bright tip). UV.x = the leaf's own wind phase,
## UV.y = 1 at the base .. 0 at the tip (how much it bends).
func _leaf(t: Buf, base: Vector2, ang: float, length: float, width: float, curl: float,
		lit_left: bool, twist: bool, phase: float, dry: bool, rigid_top := -1.0) -> Vector2:
	var segs := 6
	var p := base
	var start := t.v.size()
	for i in segs + 1:
		var f := float(i) / segs
		var a := ang + curl * f * f
		var dir := Vector2(sin(a), -cos(a))
		var perp := Vector2(-dir.y, dir.x)
		var w := width * pow(sin(PI * (0.12 + 0.88 * f)), 0.8)
		var k := lerpf(0.55, 1.1, pow(f, 0.7))
		var light_c := leaf_light * k
		var dark_c := leaf_dark * k
		if dry and f > 0.65:
			light_c = light_c.lerp(tip_dry, (f - 0.65) / 0.35 * 0.8)
			dark_c = dark_c.lerp(tip_dry * 0.7, (f - 0.65) / 0.35 * 0.8)
		var base_mix := clampf(1.0 - f * 3.0, 0.0, 1.0)
		light_c = light_c.lerp(leaf_base, base_mix * 0.6)
		dark_c = dark_c.lerp(leaf_base, base_mix * 0.6)
		var flip := lit_left != (twist and f > 0.55)
		var top := 1.0 - f if rigid_top < 0.0 else rigid_top
		t.add(p + perp * w * 0.5, light_c if flip else dark_c, Vector2(phase, top))
		t.add(p - perp * w * 0.5, dark_c if flip else light_c, Vector2(phase, top))
		if i < segs:
			p += dir * length / segs
	# degenerate joins so many leaves can share one strip
	t.join(start)
	return p


func _make_template(rng: RandomNumberGenerator) -> Buf:
	var t := Buf.new()
	var kind := rng.randi_range(0, 9)
	var leaves: Array = []
	var n := rng.randi_range(5, 8) if kind < 7 else rng.randi_range(8, 11)
	for i in n:
		var ang := rng.randf_range(-0.85, 0.85)
		if kind >= 7:
			leaves.append([rng.randf_range(-3, 3), ang * 0.7, rng.randf_range(12, 24), rng.randf_range(1.0, 1.6), signf(ang) * rng.randf_range(0.2, 0.7)])
		else:
			leaves.append([rng.randf_range(-3, 3), ang, rng.randf_range(9, 22), rng.randf_range(2.6, 4.4), signf(ang) * rng.randf_range(0.3, 1.1)])
	leaves.sort_custom(func(a, b): return a[2] > b[2])        # tall ones behind
	# thin stems with little leaves at the top (some tufts)
	if kind >= 4 and kind <= 6:
		for s in rng.randi_range(1, 3):
			var ph := rng.randf()
			var tip := _leaf(t, Vector2(rng.randf_range(-2, 2), 0), rng.randf_range(-0.3, 0.3), rng.randf_range(18, 28), 0.9,
					rng.randf_range(-0.3, 0.3), true, false, ph, false)
			for side in [-1.0, 1.0]:
				_leaf(t, tip, side * rng.randf_range(0.6, 1.1), rng.randf_range(3.0, 4.5), 1.8, side * 0.5,
						side < 0.0, false, ph, false, 1.0)
			_leaf(t, tip, rng.randf_range(-0.2, 0.2), 3.0, 1.6, 0.0, true, false, ph, false, 1.0)
	for l in leaves:
		_leaf(t, Vector2(l[0], 0), l[1], l[2], l[3], l[4], rng.randf() < 0.7, rng.randf() < 0.4, rng.randf(), rng.randf() < 0.15)
	return t


# ------------------------------------------------------------------ planting

func _plant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in variants:
		_templates.append(_make_template(rng))
	var img := mask.get_image()
	if img.is_compressed():
		img.decompress()
	var iw := img.get_width()
	var ih := img.get_height()
	var spacing := 19.0 / sqrt(density)
	var bands := {}
	var shadow := Buf.new()
	var y := spacing * 0.5
	var row := 0
	while y < map_size.y:
		var x := spacing * (0.25 if row % 2 == 0 else 0.75)
		while x < map_size.x:
			var p := Vector2(x + rng.randf_range(-0.45, 0.45) * spacing, y + rng.randf_range(-0.45, 0.45) * spacing)
			var m := img.get_pixel(clampi(int(p.x / map_size.x * iw), 0, iw - 1), clampi(int(p.y / map_size.y * ih), 0, ih - 1)).r
			if m > 0.02 and rng.randf() < m:
				var tpl: Buf = _templates[rng.randi() % _templates.size()]
				var sc := rng.randf_range(min_scale, max_scale)
				var fx := -1.0 if rng.randf() < 0.5 else 1.0
				var bi := int(p.y / BAND_HEIGHT)
				if not bands.has(bi):
					bands[bi] = Buf.new()
				var band_origin := Vector2(0, (bi + 1) * BAND_HEIGHT)
				var xf := Transform2D(0.0, Vector2(sc * fx, sc), 0.0, p - band_origin)
				(bands[bi] as Buf).add_xf(xf, tpl)
				if cast_shadows:
					var sxf := Transform2D(0.0, Vector2(sc * fx, sc * 0.5), -0.95, p)
					shadow.add_xf(sxf, tpl, false)
				tuft_count += 1
			x += spacing
		y += spacing * 0.86
		row += 1
	var parent: Node = get_node_or_null(objects_path)
	if parent == null:
		parent = self
	for bi in bands:
		var mi := MeshInstance2D.new()
		mi.name = "Grass%d" % bi
		mi.position = Vector2(0, (bi + 1) * BAND_HEIGHT)
		var b: Buf = bands[bi]
		mi.mesh = _strip(b.v, b.c, b.uv)
		mi.material = _mat
		parent.add_child(mi)
	if cast_shadows and shadow.v.size() > 0:
		var cols := PackedColorArray()
		cols.resize(shadow.v.size())
		cols.fill(Color.WHITE)
		var sh := MeshInstance2D.new()
		sh.name = "GrassShadows"
		sh.mesh = _strip(shadow.v, cols, shadow.uv)
		sh.material = _shadow_mat
		sh.z_as_relative = false
		sh.z_index = -8
		add_child(sh)


func _strip(v: PackedVector2Array, c: PackedColorArray, uv: PackedVector2Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)
	return mesh


## Called by the weather: 0 = calm, 1 = full storm (stronger, faster wind).
func set_storm(k: float) -> void:
	for m in [_mat, _shadow_mat]:
		if m == null:
			continue
		m.set_shader_parameter("sway", sway * (1.0 + 1.6 * k))
		m.set_shader_parameter("gust_lean", gust_lean * (1.0 + 1.4 * k))
		m.set_shader_parameter("flutter", flutter * (1.0 + 2.0 * k))


## Called by the world's day clock: 1 = full sun, 0 = no shadows (sunrise, sunset).
func set_shadow_strength(k: float) -> void:
	if _shadow_mat:
		_shadow_mat.set_shader_parameter("shadow_color", Color(0.02, 0.06, 0.04, 0.30 * k))


func _process(_delta: float) -> void:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		a = Vector3(p.global_position.x, p.global_position.y, bend_radius)
	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	if boss:
		b = Vector3(boss.global_position.x, boss.global_position.y, bend_radius * 1.4)
	for m in [_mat, _shadow_mat]:
		m.set_shader_parameter("bend_a", a)
		m.set_shader_parameter("bend_b", b)
