extends CharacterBody2D
## Taungoo army unit (war elephant, cavalry, the king). Marches along its Patrol Points
## back and forth with the right animation for each direction, waits at the ends,
## stands idle with a slow breath, and casts a long soft sun shadow that follows
## every animation frame (it fades at night and in storms).

## World positions to march between (in order, then back). Empty = stand still.
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var speed := 22.0
## Cavalry only: gallop with the run frames.
@export var gallop := false
@export var gallop_speed := 70.0
## Seconds to wait before starting (to march in a column behind another unit).
@export var start_delay := 0.0
@export var wait_time := 2.5
## Marching in a column: this unit's place (0 = leader) and how many units march together.
## The column waits at each end so it turns around in order, without units walking through each other.
@export var column_index := 0
@export var column_size := 1
## Seconds between units in the column.
@export var column_gap := 3.0
@export var start_facing := "s"
@export_range(0.0, 1.0, 0.05) var shadow_strength := 0.38

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _i := 0
var _dir := 1
var _wait := 0.0
var _t := 0.0
var _face := "s"
var _shadow: Sprite2D
var _base_y := 0.0


func _ready() -> void:
	add_to_group("actor")
	_face = start_facing
	_wait = start_delay + column_index * column_gap
	_base_y = sprite.offset.y
	_shadow = Sprite2D.new()
	_shadow.name = "SunShadow"
	_shadow.z_index = -1
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.skew = -0.95
	add_child(_shadow)
	move_child(_shadow, 0)
	_play("idle")


func _anim_for(base: String) -> String:
	for n in [base + "_" + _face, "walk_" + _face, base + "_s", "idle_s"]:
		if sprite.sprite_frames.has_animation(n):
			return n
	return sprite.animation


func _play(base: String) -> void:
	var a := _anim_for(base)
	if sprite.animation != a:
		var ph := 0.0
		if not sprite.animation.begins_with("idle"):
			ph = float(sprite.frame) / maxf(sprite.sprite_frames.get_frame_count(sprite.animation), 1.0)
		sprite.play(a)
		if not a.begins_with("idle"):
			sprite.frame = int(ph * sprite.sprite_frames.get_frame_count(a))


func _set_face(v: Vector2) -> void:
	var g := Vector2(v.x, v.y * 2.0)
	if g.length() < 0.01:
		return
	var ang := rad_to_deg(g.angle())          # 0 east, 90 south, -90 north
	if absf(ang - 90.0) < 35.0:
		_face = "s"
	elif absf(ang + 90.0) < 35.0:
		_face = "n"
	else:
		_face = "e" if absf(ang) < 90.0 else "w"


func _physics_process(delta: float) -> void:
	_t += delta
	var moving := false
	if patrol_points.size() > 1:
		if _wait > 0.0:
			_wait -= delta
		else:
			var target := patrol_points[_i]
			var d := target - global_position
			var sp := gallop_speed if gallop else speed
			if d.length() < 2.0:
				var at_end := _i + _dir >= patrol_points.size() or _i + _dir < 0
				if at_end:
					# who arrived first leaves last, so the column turns around in order
					var k := (column_size - 1 - column_index) if _dir > 0 else column_index
					_wait = wait_time + 2.0 * column_gap * k
					_dir = -_dir
				_i += _dir
			else:
				global_position += d.normalized() * minf(sp * delta, d.length())
				_set_face(d)
				moving = true
	if moving:
		_play("run" if gallop else "walk")
		sprite.offset.y = _base_y
	else:
		_play("idle")
		if sprite.sprite_frames.get_frame_count(sprite.animation) == 1:
			sprite.offset.y = _base_y - (0.5 + 0.5 * sin(_t * 1.8))      # slow breath
	_update_shadow()


func _update_shadow() -> void:
	_shadow.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	_shadow.flip_h = sprite.flip_h
	_shadow.offset = sprite.offset
	_shadow.position = sprite.position
	_shadow.scale = Vector2(sprite.scale.x, sprite.scale.y * 0.42)
	var w := get_tree().current_scene
	var sun := 1.0
	if w and w.has_node("Sun"):
		sun = clampf(w.get_node("Sun").energy / 0.5, 0.0, 1.2)
	_shadow.modulate = Color(0.03, 0.03, 0.08, shadow_strength * sun)
