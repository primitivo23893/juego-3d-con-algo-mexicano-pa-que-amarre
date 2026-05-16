extends Area3D

@export var velocidad_rotacion: float = 2.0 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween = create_tween().set_loops()
	var pos_y_original = position.y

	tween.tween_property(self, "position:y", pos_y_original + 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", pos_y_original, 1.0).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:

	rotate_y(velocidad_rotacion * delta)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores"):
		if body.has_method("recoger_llave"):
			body.recoger_llave()
			queue_free() 
