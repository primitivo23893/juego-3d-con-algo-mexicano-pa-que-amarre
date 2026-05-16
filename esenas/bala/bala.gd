extends Area3D

@export var velocidad: float = 15.0
var direccion_viaje: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func configurar(direccion: Vector3) -> void:
	direccion_viaje = direccion.normalized()

func _physics_process(delta: float) -> void:
	global_position += direccion_viaje * velocidad * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemigos"): 
		if body.has_method("recibir_dano"):
			body.recibir_dano() # Llama al daño directo del enemigo
		queue_free()
