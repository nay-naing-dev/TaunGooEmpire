extends CanvasLayer
## Dialogue box at the bottom of the screen (Stardew style, without a portrait):
## the speaker's name on top, their words typed out underneath.
## Open it with Game.dialogue(speaker, lines, done, choices).
##   E / Space / Enter / left click: finish typing the line, or go on to the next one.
## After the last line it closes and calls done().
## With choices, they are listed under the last line instead:
##   W / S / arrows / mouse to pick, 1-9 to pick directly, E / Space / Enter / click to choose.
## Then done(index) is called; it can open the box again right away (it stays up,
## no flicker), otherwise the box closes.

const INK := Color(0.15, 0.06, 0.08)
const PAPER := Color(1, 1, 1, 0.97)
const NAME_INK := Color(0.5, 0.2, 0.1)
const PICKED := Color(0.93, 0.85, 0.7)
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
var _choice_box: VBoxContainer
var _lines := PackedStringArray()
var _choices := PackedStringArray()
var _choosing := false
var _sel := 0
var _i := 0
var _typed := 0.0
var _done := Callable()
var _open := false
var _serial := 0
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
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_box.visible = false
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
	box.add_child(_choice_box)
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


func open(speaker: String, lines: PackedStringArray, done := Callable(), choices := PackedStringArray()) -> void:
	var was_open := _open
	_serial += 1
	_name.text = speaker
	_lines = lines
	_choices = choices
	_clear_choices()
	_i = 0
	_done = done
	_open = true
	visible = true
	_start_line()
	if was_open:
		return
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
	_text.text = _lines[_i] if _i < _lines.size() else ""
	_typed = 0.0
	_text.visible_characters = 0
	_arrow.visible = false


func _line_typed() -> bool:
	return _text.visible_characters >= _text.get_total_character_count()


func _last_line() -> bool:
	return _i + 1 >= _lines.size()


func _show_choices() -> void:
	_choosing = true
	_arrow.visible = false
	for c in _choices:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_label(18, INK))
		row.get_child(0).text = c
		_choice_box.add_child(row)
	_choice_box.visible = true
	_select(0)


func _clear_choices() -> void:
	_choosing = false
	_choice_box.visible = false
	for row in _choice_box.get_children():
		row.queue_free()
		_choice_box.remove_child(row)


func _select(i: int) -> void:
	_sel = wrapi(i, 0, _choices.size())
	for r in _choice_box.get_child_count():
		var sb: StyleBoxFlat = _choice_box.get_child(r).get_theme_stylebox("panel")
		sb.bg_color = PICKED if r == _sel else Color(PICKED, 0.0)


## The choice row under a screen position, or -1.
func _row_at(pos: Vector2) -> int:
	for r in _choice_box.get_child_count():
		if (_choice_box.get_child(r) as Control).get_global_rect().has_point(pos):
			return r
	return -1


func _choose(i: int) -> void:
	var done := _done
	_done = Callable()
	var serial := _serial
	if done.is_valid():
		done.call(i)
	if _serial == serial:  # done didn't open a new dialogue
		close(false)


func _pressed(event: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var next := click or _pressed(event, ["ui_accept", "interact"])
	if _choosing:
		_choice_input(event, next, click)
		return
	if not next:
		return
	get_viewport().set_input_as_handled()
	if not _line_typed():
		_typed = INF
	elif not _last_line():
		_i += 1
		_start_line()
	elif not _choices.is_empty():
		_show_choices()
	else:
		close()


func _choice_input(event: InputEvent, next: bool, click: bool) -> void:
	if event is InputEventMouseMotion:
		var r := _row_at(event.position)
		if r >= 0 and r != _sel:
			_select(r)
		return
	if _pressed(event, ["ui_up", "move_up"]):
		_select(_sel - 1)
	elif _pressed(event, ["ui_down", "move_down"]):
		_select(_sel + 1)
	elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + _choices.size():
		_select(event.keycode - KEY_1)
		_choose(_sel)
	elif click:
		var r := _row_at(event.position)
		if r >= 0:
			_choose(r)
	elif next:
		_choose(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _open:
		_typed += delta * TYPE_SPEED
		_text.visible_characters = mini(int(minf(_typed, 1e6)), _text.get_total_character_count())
		if _line_typed() and _last_line() and not _choices.is_empty() and not _choosing:
			_show_choices()  # the question's answers come up as soon as it is typed
		_arrow.visible = _line_typed() and not _choosing
		_arrow.modulate.a = 0.55 + 0.45 * sin(_t * 6.0)
	var view := get_viewport().get_visible_rect().size
	var w := minf(view.x - 48.0, MAX_WIDTH)
	_panel.custom_minimum_size.x = w
	_panel.reset_size()
	_panel.position = Vector2((view.x - w) * 0.5, view.y - _panel.size.y - 24.0 + _rise).round()
