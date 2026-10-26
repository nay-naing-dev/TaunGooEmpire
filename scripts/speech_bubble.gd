extends CanvasLayer
## Speech bubble over a character's head. Drawn on screen (not in the world),
## so the text stays crisp at any camera zoom and is not darkened at night.
## Add it as a child of the character, then:
##   say(text)   - show a line for a while (longer lines stay up longer)
##   hint(true)  - show a small "E" while the player is in reach and nothing is said

## How far above the character's feet the bubble's tail points (world pixels).
@export var head_height := 80.0
@export var max_width := 220.0
@export var font_size := 14

const INK := Color(0.15, 0.06, 0.08)
const PAPER := Color(1, 0.96, 0.88, 0.95)

var _who: Node2D
var _panel: PanelContainer
var _label: Label
var _left := 0.0
var _hint := false
var _tw: Tween


func _ready() -> void:
	layer = 5  # under the house enter / leave fade (layer 9)
	_who = get_parent() as Node2D
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", INK)
	_panel.add_child(_label)
	# little tail under the bubble, pointing at the head
	var tail := Polygon2D.new()
	tail.name = "Tail"
	tail.color = INK
	tail.polygon = PackedVector2Array([Vector2(-7, -2), Vector2(7, -2), Vector2(0, 8)])
	var fill := Polygon2D.new()
	fill.color = PAPER
	fill.polygon = PackedVector2Array([Vector2(-4.5, -3), Vector2(4.5, -3), Vector2(0, 4.5)])
	tail.add_child(fill)
	_panel.add_child(tail)
	add_child(_panel)
	_panel.modulate.a = 0.0
	_panel.visible = false


## Shows a line over the head. duration < 0: time it from the line's length.
func say(text: String, duration := -1.0) -> void:
	_left = duration if duration > 0.0 else 2.0 + text.length() * 0.05
	_show(text)


func is_talking() -> bool:
	return _left > 0.0


func hint(on: bool) -> void:
	if on == _hint:
		return
	_hint = on
	if _left <= 0.0:
		_show("E" if on else "")


func _show(text: String) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	if text == "":
		_tw.tween_property(_panel, "modulate:a", 0.0, 0.2)
		_tw.tween_callback(_panel.hide)
		return
	_label.text = text
	var w := _label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_label.custom_minimum_size.x = minf(ceilf(w) + 2.0, max_width)
	_panel.reset_size()
	_panel.show()
	_panel.scale = Vector2(0.85, 0.85)
	_tw.set_parallel()
	_tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
	_tw.tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _who == null:
		return
	visible = _who.is_visible_in_tree()
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_show("E" if _hint else "")
	if not _panel.visible:
		return
	_panel.reset_size()
	var tip := get_viewport().get_canvas_transform() * (_who.global_position + Vector2(0, -head_height))
	_panel.pivot_offset = Vector2(_panel.size.x * 0.5, _panel.size.y)
	_panel.position = (tip - Vector2(_panel.size.x * 0.5, _panel.size.y + 8.0)).round()
	_panel.get_node("Tail").position = Vector2(_panel.size.x * 0.5, _panel.size.y)
