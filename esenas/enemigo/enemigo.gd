extends CharacterBody3D

const GRID_SIZE = 1.0
var is_moving = false

@onready var ray_arriba = $RayCastFloorArriba
@onready var ray_abajo = $RayCastFloorAbajo
@onready var ray_derecha = $RayCastFloorDerecha
@onready var ray_izquierda = $RayCastFloorIzquierda

var limite_z_max: float = 99999.0
var limite_z_min: float = -99999.0
var chunk_actual: int = 0

# --- VARIABLES DE DIFICULTAD E IA ---
var tiempo_movimiento: float = 0.5 
var radio_deteccion: float = 6.0
var probabilidad_llave: float = 0.15

# CARGAMOS LA ESCENA DE LA LLAVE
var llave_scene = preload("res://esenas/llave/llave.tscn") 

func _ready() -> void:
	add_to_group("enemigos")
	$Sprite.animation = str(randi_range(0,3))
	var twn = create_tween().set_loops()
	twn.tween_property($Sprite,"flip_h",false,0.2)
	twn.tween_property($Sprite,"flip_h",true,0.2)


func set_limites_chunk(indice: int, largo: int):
	chunk_actual = indice
	limite_z_max = -(indice * largo) + 0.5
	limite_z_min = -((indice + 1) * largo) + 0.5
	tiempo_movimiento = max(0.5 - (indice * 0.02), 0.15)

func recibir_dano(): # Modificado: ya no requiere ID de atacante
	var enemigos_en_chunk = get_tree().get_nodes_in_group("enemigos_chunk_" + str(chunk_actual))
	
	if enemigos_en_chunk.size() <= 1 or randf() < probabilidad_llave:
		soltar_llave()
		
	# COOPERATIVO: Accedemos a la escena actual y sumamos al método global
	var escena_principal = get_tree().current_scene
	if escena_principal and escena_principal.has_method("registrar_baja_global"):
		escena_principal.registrar_baja_global()
		
	remove_from_group("enemigos_chunk_" + str(chunk_actual))
	queue_free()

func soltar_llave():
	if llave_scene:
		var nueva_llave = llave_scene.instantiate()
		get_tree().current_scene.call_deferred("add_child", nueva_llave)
		nueva_llave.global_position = global_position
		nueva_llave.add_to_group("chunk_" + str(chunk_actual))

func _physics_process(_delta: float) -> void:
	if is_moving:
		return
	mover_inteligente()

func mover_inteligente():
	ray_arriba.force_raycast_update()
	ray_abajo.force_raycast_update()
	ray_derecha.force_raycast_update()
	ray_izquierda.force_raycast_update()

	var opciones = [
		{"ray": ray_arriba, "dir": Vector3(1, 0, 0)},
		{"ray": ray_abajo, "dir": Vector3(-1, 0, 0)},
		{"ray": ray_derecha, "dir": Vector3(0, 0, 1)},
		{"ray": ray_izquierda, "dir": Vector3(0, 0, -1)}
	]

	var validas = []
	var escena_principal = get_tree().current_scene

	for opcion in opciones:
		if opcion.ray.is_colliding():
			var destino_tentativo = global_position + (opcion.dir * GRID_SIZE)
			if destino_tentativo.z > limite_z_max or destino_tentativo.z < limite_z_min: continue
			if escena_principal.has_method("es_casilla_bloqueada") and escena_principal.es_casilla_bloqueada(destino_tentativo): continue
			validas.append(opcion)

	if validas.size() > 0:
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		var objetivo = null
		var dist_min = radio_deteccion
		
		for j in jugadores:
			var d = global_position.distance_to(j.global_position)
			if d < dist_min:
				dist_min = d
				objetivo = j
				
		var elegida = null
		if objetivo:
			var mejor_dist = 99999.0
			for op in validas:
				var pos_futura = global_position + (op.dir * GRID_SIZE)
				var dist_futura = pos_futura.distance_to(objetivo.global_position)
				if dist_futura < mejor_dist:
					mejor_dist = dist_futura
					elegida = op
		else:
			elegida = validas.pick_random()

		var destino = global_position + (elegida.dir * GRID_SIZE)
		var floor_y = elegida.ray.get_collision_point().y
		destino.y = floor_y + 1.0 
		
		move_to(destino)

func move_to(target_pos: Vector3):
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, tiempo_movimiento)
	await tween.finished
	is_moving = false
