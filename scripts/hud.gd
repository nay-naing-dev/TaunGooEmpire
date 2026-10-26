extends CanvasLayer
## Health bars and fight messages for the top-down world.
## Built in code, so there is no scene to set up: world.gd creates it.

var _player_bar: ProgressBar
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _banner: Label


func _ready() -> void:
	layer = 10
	_player_bar = _bar(Color(0.85, 0.2, 0.25), Vector2(260, 18))
	var pbox := _panel(Vector2(20, 20))
	var plabel := _label("HP", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(plabel)
	row.add_child(_player_bar)
	pbox.add_child(row)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.position = Vector2(-310, -86)
	_boss_box.custom_minimum_size = Vector2(620, 0)
	_boss_name = _label("", 20)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = _bar(Color(0.75, 0.12, 0.12), Vector2(620, 20))
	_boss_box.add_child(_boss_name)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	add_child(_boss_box)

	_banner = _label("", 56)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)


func watch_player(p: Node) -> void:
	_player_bar.max_value = p.max_health
	_player_bar.value = p.health
	p.health_changed.connect(func(c, m): _tween_bar(_player_bar, c, m))
	p.died.connect(_on_player_died)


func watch_boss(b: Node) -> void:
	b.engaged.connect(func(_boss):
		_boss_name.text = b.display_name
		_boss_bar.max_value = b.max_health
		_boss_bar.value = b.health
		_boss_box.visible = true
		show_banner("A cursed king awakens", Color(1, 0.55, 0.45), 1.6))
	b.health_changed.connect(func(c, m):
		_tween_bar(_boss_bar, c, m)
		if c == m and b.state == b.State.DORMANT:
			_boss_box.visible = false)
	b.defeated.connect(func():
		show_banner("VICTORY", Color(1, 0.85, 0.45), 3.0)
		get_tree().create_timer(2.5).timeout.connect(func(): _boss_box.visible = false))


func show_banner(text: String, color: Color, secs: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(secs)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_player_died() -> void:
	show_banner("YOU FELL", Color(0.9, 0.3, 0.3), 2.0)
	get_tree().create_timer(3.0).timeout.connect(func(): get_tree().reload_current_scene())


func _tween_bar(bar: ProgressBar, value: int, maximum: int) -> void:
	bar.max_value = maximum
	create_tween().tween_property(bar, "value", float(value), 0.25)


func _bar(fill: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.07, 0.85)
	bg.border_color = Color(0.85, 0.66, 0.36)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 0.93, 0.82))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.06, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _panel(pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.06, 0.1, 0.6)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	add_child(p)
	return p
