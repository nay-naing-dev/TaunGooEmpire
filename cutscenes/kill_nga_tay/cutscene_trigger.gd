extends Node
## Test trigger for the Nga Tay kill cutscene.
## Drag cutscene_trigger.tscn into the forest map (anywhere). Then:
##   - kill the boss bandit  -> the cutscene plays
##   - or press F9 any time  -> plays it at once (quick test)
## By default the boss is the node named "Bandit2" (the big brute). Pick another one
## with `boss` in the Inspector, or change `boss_name`.

@export var boss: NodePath
@export var boss_name := "Bandit2"
@export var delay_after_death := 1.0     ## let the fall play before cutting away
@export var test_key: Key = KEY_F9
@export var play_once := true

const CUTSCENE := preload("res://cutscenes/kill_nga_tay/kill_cutscene.tscn")
var _playing := false
var _played := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hook.call_deferred()


func _hook() -> void:
	var b: Node = get_node_or_null(boss) if not boss.is_empty() else null
	if b == null and get_tree().current_scene:
		b = get_tree().current_scene.find_child(boss_name, true, false)
	if b and b.has_signal("died"):
		b.died.connect(_on_boss_died)
		print("[cutscene_trigger] watching ", b.name)
	else:
		push_warning("[cutscene_trigger] boss not found - use F9 to test")


func _on_boss_died() -> void:
	await get_tree().create_timer(delay_after_death).timeout
	play()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == test_key:
		play()


func play() -> void:
	if _playing or (play_once and _played):
		return
	_playing = true
	var cs = CUTSCENE.instantiate()
	get_tree().root.add_child(cs)
	cs.play()
	await cs.finished
	_playing = false
	_played = true
