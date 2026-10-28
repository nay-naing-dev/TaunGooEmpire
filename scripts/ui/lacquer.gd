class_name Lacquer
## Shared look for the menu windows (inventory, current quests): a carved teak frame
## on red lacquer with gold inlay, a gilded name board across the top with a little
## spire on it (pixel art at 2x in res://ui/inventory/).

const INK := Color(0.15, 0.06, 0.08)
const GOLD_TEXT := Color(1, 0.87, 0.5)
const CREAM := Color(0.96, 0.88, 0.72)
const PANEL_TEX := preload("res://ui/inventory/panel.png")
const PLAQUE_TEX := preload("res://ui/inventory/plaque.png")
const CREST_TEX := preload("res://ui/inventory/crest.png")


## Dims the screen behind it and puts a framed window on root, `drop` px below the
## middle of the screen, with `title` on its name board. Add the content to the
## returned panel.
static func window(root: Control, title: String, drop: float) -> PanelContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = drop * 2.0  # centred in what is left, so `drop` lower than the middle
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := framed(PANEL_TEX, 32, 36, 40, 36, 32)
	center.add_child(panel)

	# the name board sits across the top of the frame, the spire on top of it
	var plaque := framed(PLAQUE_TEX, 0, 44, 6, 44, 6)
	var board: StyleBoxTexture = plaque.get_theme_stylebox("panel")
	board.texture_margin_left = 36  # only the pointed ends stay unstretched
	board.texture_margin_right = 36
	plaque.custom_minimum_size = Vector2(220, PLAQUE_TEX.get_height())
	var name_label := label(title, 20, GOLD_TEXT)
	name_label.add_theme_color_override("font_outline_color", INK)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(name_label)
	root.add_child(plaque)
	var crest := TextureRect.new()
	crest.texture = CREST_TEX
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crest)
	panel.item_rect_changed.connect(func():
		var r := panel.get_global_rect()
		plaque.reset_size()
		plaque.position = Vector2(r.get_center().x - plaque.size.x * 0.5, r.position.y + 10 - plaque.size.y * 0.5)
		crest.position = Vector2(r.get_center().x - CREST_TEX.get_width() * 0.5, plaque.position.y - CREST_TEX.get_height() + 8))
	return panel


## A panel drawn with a 9-sliced texture: `edge` px of each side stay unstretched.
static func framed(tex: Texture2D, edge: int, left: int, top: int, right: int, bottom: int) -> PanelContainer:
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


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
