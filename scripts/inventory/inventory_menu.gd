extends CanvasLayer
## Inventory screen (Stardew style): B opens / closes it, Esc closes it too.
## The world pauses while it is open. Shows Game.inventory as a grid of slots.
##   Mouse: hover for the item's name and description, left click picks a stack up
##          and puts it down (on an empty slot, the same item to stack, or another
##          item to swap), right click takes one.
##   Keys:  W A S D / arrows move, E / Space / Enter = left click.
## Game creates it; it follows the bag's size, so a bigger bag just adds rows.

## Looks: carved teak frame on red lacquer, black-lacquer slot wells, a gilded name
## board with a little spire, and palm-leaf tooltips (res://ui/inventory/, pixel art at 2x).

const INK := Color(0.15, 0.06, 0.08)
const NAME_INK := Color(0.5, 0.2, 0.1)
const GOLD_TEXT := Color(1, 0.87, 0.5)
const CREAM := Color(0.96, 0.88, 0.72)
const PANEL_TEX := preload("res://ui/inventory/panel.png")
const PLAQUE_TEX := preload("res://ui/inventory/plaque.png")
const CREST_TEX := preload("res://ui/inventory/crest.png")
const TIP_TEX := preload("res://ui/inventory/tooltip.png")
const COLUMNS := 12
const SLOT_SIZE := 56.0
## How far below the middle of the screen the window sits.
const DROP := 70.0

var inventory: Inventory
var _root: Control
var _panel: PanelContainer
var _plaque: PanelContainer
var _crest: TextureRect
var _grid: GridContainer
var _tip: PanelContainer
var _tip_name: Label
var _tip_text: Label
var _held_view: Slot
var _held: Inventory.Stack
var _sel := 0
var _mouse := true  # last moved with the mouse (else the keys)
var _tw: Tween


## One square of the grid (also used for the stack held under the mouse).
class Slot extends Control:
	const WELL := preload("res://ui/inventory/slot.png")
	const WELL_SELECTED := preload("res://ui/inventory/slot_selected.png")

	var stack: Inventory.Stack
	var selected := false
	var plain := false  # no background: the held stack

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if not plain:
			draw_texture_rect(WELL_SELECTED if selected else WELL, r, false)
		if stack == null:
			return
		var font := ThemeDB.fallback_font
		var inner := r.grow(-9.0)
		if stack.item.icon:
			var t := stack.item.icon
			var k := minf(inner.size.x / t.get_width(), inner.size.y / t.get_height())
			var s := t.get_size() * k
			draw_texture_rect(t, Rect2(inner.position + (inner.size - s) * 0.5, s), false)
		else:
			# no icon yet: the first letters of its name
			var abbr := stack.item.display_name.substr(0, 3) if stack.item.display_name != "" else "?"
			draw_string(font, Vector2(0, size.y * 0.5 + 6), abbr, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.96, 0.88, 0.72))
		if stack.count > 1:
			var p := Vector2(0, size.y - 5)
			draw_string_outline(font, p, str(stack.count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, 15, 5, Color(0.15, 0.06, 0.08))
			draw_string(font, p, str(stack.count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, 15, Color(1, 0.96, 0.88))


func _ready() -> void:
	layer = 12  # above the HUD and the dialogue box
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = DROP * 2.0  # centred in what is left, so DROP lower than the middle
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = _framed(PANEL_TEX, 32, 36, 40, 36, 32)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)
	var help := _label("Click: pick up / put down     Right click: take one     B / Esc: close", 13, Color(CREAM, 0.75))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)

	# the name board sits across the top of the frame, the spire on top of it
	_plaque = _framed(PLAQUE_TEX, 0, 44, 6, 44, 6)
	var board: StyleBoxTexture = _plaque.get_theme_stylebox("panel")
	board.texture_margin_left = 36  # only the pointed ends stay unstretched
	board.texture_margin_right = 36
	_plaque.custom_minimum_size = Vector2(220, PLAQUE_TEX.get_height())
	var title := _label("Inventory", 20, GOLD_TEXT)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plaque.add_child(title)
	_root.add_child(_plaque)
	_crest = TextureRect.new()
	_crest.texture = CREST_TEX
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crest)
	_panel.item_rect_changed.connect(_place_title)

	_tip = _framed(TIP_TEX, 16, 14, 10, 14, 10)
	var tbox := VBoxContainer.new()
	_tip_name = _label("", 18, NAME_INK)
	_tip_text = _label("", 15, INK)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.custom_minimum_size.x = 240
	tbox.add_child(_tip_name)
	tbox.add_child(_tip_text)
	_tip.add_child(tbox)
	_tip.visible = false
	_root.add_child(_tip)

	_held_view = Slot.new()
	_held_view.plain = true
	_held_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_view.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_root.add_child(_held_view)
	visible = false


## A panel drawn with a 9-sliced texture: `edge` px of each side stay unstretched.
func _framed(tex: Texture2D, edge: int, left: int, top: int, right: int, bottom: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(edge)
	sb.content_margin_left = left
	sb.content_margin_top = top
	sb.content_margin_right = right
	sb.content_margin_bottom = bottom
	p.add_theme_stylebox_override("panel", sb)
	return p


func _place_title() -> void:
	var r := _panel.get_global_rect()
	_plaque.reset_size()
	_plaque.position = Vector2(r.get_center().x - _plaque.size.x * 0.5, r.position.y + 10 - _plaque.size.y * 0.5)
	_crest.position = Vector2(r.get_center().x - CREST_TEX.get_width() * 0.5, _plaque.position.y - CREST_TEX.get_height() + 8)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func set_inventory(inv: Inventory) -> void:
	inventory = inv
	inventory.changed.connect(_refresh)


func is_open() -> bool:
	return visible


func can_open() -> bool:
	return not visible and not get_tree().paused and not Game.in_dialogue() \
			and get_tree().get_first_node_in_group("player") != null


func open() -> void:
	visible = true
	get_tree().paused = true
	_build()
	_refresh()
	_root.modulate.a = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not visible:
		return
	_stow_held()
	visible = false
	get_tree().paused = false


## Makes one Slot per bag slot (again, if the bag grew).
func _build() -> void:
	if _grid.get_child_count() == inventory.size():
		return
	for c in _grid.get_children():
		c.queue_free()
		_grid.remove_child(c)
	for i in inventory.size():
		var s := Slot.new()
		s.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(s)
	_sel = clampi(_sel, 0, inventory.size() - 1)


func _refresh() -> void:
	if not visible:
		return
	for i in _grid.get_child_count():
		var s: Slot = _grid.get_child(i)
		s.stack = inventory.get_stack(i)
		s.selected = i == _sel
		s.queue_redraw()
	_held_view.stack = _held
	_held_view.visible = _held != null
	_held_view.queue_redraw()
	_update_tip()


func _update_tip() -> void:
	var s: Inventory.Stack = inventory.get_stack(_sel)
	_tip.visible = s != null and _held == null
	if not _tip.visible:
		return
	_tip_name.text = s.item.display_name
	_tip_text.text = s.item.description
	_tip_text.visible = s.item.description != ""
	_tip.reset_size()


## Back into the bag before closing: onto the same item first, else an empty slot.
func _stow_held() -> void:
	if _held == null:
		return
	for pass_empty in [false, true]:
		for i in inventory.size():
			if _held == null:
				break
			var s: Inventory.Stack = inventory.get_stack(i)
			if (s == null) == pass_empty and (s == null or (s.item == _held.item and s.count < s.item.max_stack)):
				_held = inventory.put(i, _held)
	if _held:
		push_warning("Inventory: no room to put %s back" % _held.item.id)
	_held = null


func _slot_at(pos: Vector2) -> int:
	for i in _grid.get_child_count():
		if (_grid.get_child(i) as Control).get_global_rect().has_point(pos):
			return i
	return -1


func _select(i: int) -> void:
	if i == _sel or i < 0:
		return
	_sel = i
	_refresh()


func _pressed(event: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _input(event: InputEvent) -> void:
	if inventory == null or event.is_echo():
		return
	if not visible:
		if _pressed(event, ["inventory"]) and can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	get_viewport().set_input_as_handled()  # the paused world gets nothing while it is open
	if _pressed(event, ["inventory", "ui_cancel"]):
		close()
	elif event is InputEventMouseMotion:
		_mouse = true
		_select(_slot_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		var i := _slot_at(event.position)
		if i >= 0:
			_select(i)
			if event.button_index == MOUSE_BUTTON_LEFT:
				_click(i)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_take_one(i)
	elif _pressed(event, ["ui_left", "move_left"]):
		_key_move(-1, 0)
	elif _pressed(event, ["ui_right", "move_right"]):
		_key_move(1, 0)
	elif _pressed(event, ["ui_up", "move_up"]):
		_key_move(0, -1)
	elif _pressed(event, ["ui_down", "move_down"]):
		_key_move(0, 1)
	elif _pressed(event, ["ui_accept", "interact"]):
		_mouse = false
		_click(_sel)


func _key_move(dx: int, dy: int) -> void:
	_mouse = false
	var rows := ceili(inventory.size() / float(COLUMNS))
	var col := wrapi(_sel % COLUMNS + dx, 0, COLUMNS)
	var row := wrapi(_sel / COLUMNS + dy, 0, rows)
	_select(mini(row * COLUMNS + col, inventory.size() - 1))


## Pick the stack up, or put the held one down / stack it / swap it.
func _click(i: int) -> void:
	if _held == null:
		_held = inventory.take(i)
	else:
		_held = inventory.put(i, _held)
	_refresh()


## Right click: one more of that item into the hand.
func _take_one(i: int) -> void:
	var s: Inventory.Stack = inventory.get_stack(i)
	if s == null:
		return
	if _held == null:
		_held = inventory.split(i, 1)
	elif _held.item == s.item and _held.count < _held.item.max_stack:
		inventory.split(i, 1)
		_held.count += 1
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	var anchor: Vector2
	if _mouse:
		anchor = _root.get_global_mouse_position()
	else:
		var r := (_grid.get_child(_sel) as Control).get_global_rect()
		anchor = r.position + Vector2(r.size.x * 0.6, r.size.y * 0.6)
	_held_view.position = anchor - _held_view.size * 0.5 + Vector2(10, 10)
	if _tip.visible:
		var view := _root.get_viewport_rect().size
		var p := anchor + Vector2(18, 18)
		p.x = minf(p.x, view.x - _tip.size.x - 8)
		p.y = minf(p.y, view.y - _tip.size.y - 8)
		_tip.position = p
