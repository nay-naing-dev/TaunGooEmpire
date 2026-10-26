extends StaticBody2D
## Interior furniture. lift > 0: it sits on a table/bench (no collision, drawn raised).
@export var lift := 0.0


func _ready() -> void:
	if lift > 0.0:
		$Sprite2D.offset.y -= lift * 2.0
		$CollisionPolygon2D.queue_free()
