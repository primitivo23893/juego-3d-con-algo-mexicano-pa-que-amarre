extends Area3D 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var tween = create_tween().set_loops()
	var pos_y_original = position.y
	
	tween.tween_property(self, "position:y", pos_y_original + 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", pos_y_original, 1.0).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores"):
		print("¡Mejora recogida por: ", body.name, "!")
		
		$MeshInstance3D.hide()
		
		$CollisionShape3D.set_deferred("disabled", true)
		
		$CPUParticles3D.emitting = true

		await get_tree().create_timer($CPUParticles3D.lifetime).timeout
		
		queue_free()
