extends CanvasLayer
## Dialogue box at the bottom of the screen (Stardew style, without a portrait):
## the speaker's name on top, their words typed out underneath.
## Open it with Game.dialogue(speaker, lines, done).
##   E / Space / Enter / left click: finish typing the line, or go on to the next one.
## After the last line it closes and calls done.

const INK := Color(0.15, 0.06, 0.08)
const PAPER := Color(1, 1, 1, 0.97)
const NAME_INK := Color(0.5, 0.2, 0.1)
## Letters typed per second.
const TYPE_SPEED := 45.0
const MAX_WIDTH := 860.0
## How long after closing it still counts as busy, so the key that closed it
## doesn't also start talking to someone again in the same frame.
const CLOSE_GRACE_MS := 200

var _panel: PanelContainer
var _name: Label
var _text: Label
var _arrow: Arrow
var _lines := PackedStringArray()
var _i := 0
var _typed := 0.0
var _done := Callable()
var _open := false
var _closed_at := -CLOSE_GRACE_MS
var _rise := 0.0
var _t := 0.0
var _tw: Tween


## Little "more" triangle in the bottom right corner once a line is fully typed.
class Arrow extends Control:
	var color := Color(0.15, 0.06, 0.08)

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x * 0.5, size.y)]), color)


func _ready() -> void:
	layer = 11  # above the HUD (10)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	_panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_name = _label(22, NAME_INK)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.25)
	rule.custom_minimum_size = Vector2(0, 2)
	_text = _label(19, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # words don't jump lines while typing
	_text.custom_minimum_size.y = 84  # room for three lines, so the box doesn't change size
	var foot := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arrow = Arrow.new()
	_arrow.custom_minimum_size = Vector2(14, 9)
	foot.add_child(spacer)
	foot.add_child(_arrow)
	box.add_child(_name)
	box.add_child(rule)
	box.add_child(_text)
	box.add_child(foot)
	_panel.add_child(box)
	add_child(_panel)
	_panel.modulate.a = 0.0
	visible = false


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func open(speaker: String, lines: PackedStringArray, done := Callable()) -> void:
	_name.text = speaker
	_lines = lines
	_i = 0
	_done = done
	_open = true
	visible = true
	_start_line()
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_tw.tween_method(func(v: float): _rise = v, 16.0, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## finished = false: closed early (scene change etc), done is not called.
func close(finished := true) -> void:
	if not _open:
		return
	_open = false
	_closed_at = Time.get_ticks_msec()
	var done := _done
	_done = Callable()
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_panel, "modulate:a", 0.0, 0.15)
	_tw.tween_callback(hide)
	if finished and done.is_valid():
		done.call()


func is_open() -> bool:
	return _open


## Open, or closed only a moment ago.
func busy() -> bool:
	return _open or Time.get_ticks_msec() - _closed_at < CLOSE_GRACE_MS


func _start_line() -> void:
	_text.text = _lines[_i]
	_typed = 0.0
	_text.visible_characters = 0
	_arrow.visible = false


func _line_typed() -> bool:
	return _text.visible_characters >= _text.get_total_character_count()


func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	var next: bool = event.is_action_pressed("ui_accept") \
			or (InputMap.has_action("interact") and event.is_action_pressed("interact")) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not next:
		return
	get_viewport().set_input_as_handled()
	if not _line_typed():
		_typed = INF
	elif _i + 1 < _lines.size():
		_i += 1
		_start_line()
	else:
		close()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _open:
		_typed += delta * TYPE_SPEED
		_text.visible_characters = mini(int(minf(_typed, 1e6)), _text.get_total_character_count())
		_arrow.visible = _line_typed()
		_arrow.modulate.a = 0.55 + 0.45 * sin(_t * 6.0)
	var view := get_viewport().get_visible_rect().size
	var w := minf(view.x - 48.0, MAX_WIDTH)
	_panel.custom_minimum_size.x = w
	_panel.reset_size()
	_panel.position = Vector2((view.x - w) * 0.5, view.y - _panel.size.y - 24.0 + _rise).round()
