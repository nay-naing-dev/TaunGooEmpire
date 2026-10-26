extends Area2D
## Walk into this zone to travel to another map.
## target_scene: the map to load.  spawn_marker: name of a Marker2D in that map
## where you arrive (e.g. "FromVillage").  Leave empty to use its PlayerSpawn.

@export_file("*.tscn") var target_scene := ""
@export var spawn_marker := ""
var _armed := false


func _ready() -> void:
	body_entered.connect(_on_body)
	# don't fire on the frame you arrive in the map
	await get_tree().create_timer(0.6).timeout
	_armed = true


func _on_body(b: Node) -> void:
	if not _armed or not b.is_in_group("player") or target_scene == "":
		return
	_armed = false
	Game.next_spawn = spawn_marker
	var layer := CanvasLayer.new()
	layer.layer = 10
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	get_tree().root.add_child(layer)
	var t := create_tween()
	t.tween_property(r, "color:a", 1.0, 0.35)
	await t.finished
	Game.go(target_scene)
	var t2 := layer.create_tween()
	t2.tween_interval(0.1)
	t2.tween_property(r, "color:a", 0.0, 0.4)
	t2.tween_callback(layer.queue_free)
