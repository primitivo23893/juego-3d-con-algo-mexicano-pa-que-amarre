extends Area3D 

enum TipoMejora { ARMA, ESCUDO, VELOCIDAD }
@export var tipo_mejora: TipoMejora = TipoMejora.ARMA

@onready var mesh = $Gun
@onready var collision = $CollisionShape3D
@onready var particle = $CPUParticles3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var tween_flotar = create_tween().set_loops()
	var pos_y_original = position.y
	tween_flotar.tween_property(self, "position:y", pos_y_original + 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween_flotar.tween_property(self, "position:y", pos_y_original, 1.0).set_trans(Tween.TRANS_SINE)

	var tween_rotar = create_tween().set_loops()
	tween_rotar.tween_property(self, "rotation_degrees:y", 360.0, 2.0).as_relative()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores"):
		if body.has_method("recibir_mejora"):
			body.recibir_mejora(tipo_mejora)
		
		# Le decimos al mapa que nos regenere
		var principal = get_tree().current_scene
		if principal.has_method("recolocar_mejora"):
			var chunk_idx = -1
			for group in get_groups():
				if String(group).begins_with("chunk_"):
					chunk_idx = int(String(group).replace("chunk_", ""))
					break
			principal.recolocar_mejora(chunk_idx)
		
		mesh.hide()
		collision.set_deferred("disabled", true)
		
		queue_free()
