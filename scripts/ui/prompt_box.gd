extends CanvasLayer
## Small box in the middle of the screen: a line of text and a row of buttons
## ("Sleep through the night?" Yes / No, or just OK). Open it with
## Game.prompt(text, buttons, done). The world is paused and greyed out behind it,
## and nothing else can be done until a button is picked:
##   A / D / arrows / mouse to pick, E / Space / Enter / click to choose.
## Then it closes and done(index) is called.
## Looks: the Lacquer window (red lacquer in a teak frame), gold-rimmed buttons.

const BUTTON_INK := Color(0.1, 0.04, 0.04)
const BUTTON_LIT := Color(0.45, 0.1, 0.08)
const RIM := Color(0.72, 0.55, 0.24)
const RIM_LIT := Color(1, 0.87, 0.5)
## How long after closing it still counts as busy, so the key that closed it
## doesn't also use the bed (or wave) again in the same frame.
const CLOSE_GRACE_MS := 200

var _root: Control
var _gray: ShaderMaterial
var _text: Label
var _row: HBoxContainer
var _buttons: Array[Button] = []
var _sel := 0
var _done := Callable()
var _open := false
var _closed_at := -CLOSE_GRACE_MS
var _tw: Tween


func _ready() -> void:
	layer = 13  # above the HUD, the dialogue box and the menus
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var gray := ColorRect.new()
	gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	gray.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks never reach the world
	_gray = ShaderMaterial.new()
	_gray.shader = preload("res://environment/fx/gray_screen.gdshader")
	gray.material = _gray
	_root.add_child(gray)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := Lacquer.framed(Lacquer.PANEL_TEX, 32, 40, 34, 40, 30)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_text = Lacquer.label("", 20, Lacquer.CREAM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_color_override("font_outline_color", Lacquer.INK)
	_text.add_theme_constant_override("outline_size", 4)
	_text.custom_minimum_size.x = 300
	box.add_child(_text)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	box.add_child(_row)
	visible = false


func open(text: String, buttons: PackedStringArray, done := Callable()) -> void:
	_text.text = text
	_done = done
	for b in _buttons:
		_row.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for i in buttons.size():
		var b := _button(buttons[i])
		b.pressed.connect(_choose.bind(i))
		b.mouse_entered.connect(_select.bind(i))
		_row.add_child(b)
		_buttons.append(b)
	_select(0)
	_open = true
	visible = true
	get_tree().paused = true
	_root.modulate.a = 0.0
	_gray.set_shader_parameter("amount", 0.0)
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(_root, "modulate:a", 1.0, 0.12)
	_tw.tween_property(_gray, "shader_parameter/amount", 1.0, 0.25)


## Open, or closed only a moment ago.
func busy() -> bool:
	return _open or Time.get_ticks_msec() - _closed_at < CLOSE_GRACE_MS


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # picked with _select, not Godot's focus
	b.custom_minimum_size = Vector2(110, 40)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, Lacquer.GOLD_TEXT)
	return b


func _style(lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUTTON_LIT if lit else BUTTON_INK
	sb.border_color = RIM_LIT if lit else RIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb


func _select(i: int) -> void:
	_sel = wrapi(i, 0, _buttons.size())
	for j in _buttons.size():
		var sb := _style(j == _sel)
		for state in ["normal", "hover", "pressed"]:
			_buttons[j].add_theme_stylebox_override(state, sb)


func _choose(i: int) -> void:
	if not _open:
		return
	_open = false
	_closed_at = Time.get_ticks_msec()
	visible = false
	get_tree().paused = false
	var done := _done
	_done = Callable()
	if done.is_valid():
		done.call(i)


func _pressed(event: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not _open or event is InputEventMouse:
		return  # the mouse goes to the buttons (the grey cover stops it there)
	get_viewport().set_input_as_handled()  # the paused world gets nothing (Esc included)
	if event.is_echo():
		return
	if _pressed(event, ["ui_left", "move_left"]):
		_select(_sel - 1)
	elif _pressed(event, ["ui_right", "move_right"]):
		_select(_sel + 1)
	elif _pressed(event, ["ui_accept", "interact"]):
		_choose(_sel)
