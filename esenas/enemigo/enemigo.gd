extends CharacterBody3D

const GRID_SIZE = 1.0
var is_moving = false


@onready var ray_arriba = $RayCastFloorArriba
@onready var ray_abajo = $RayCastFloorAbajo
@onready var ray_derecha = $RayCastFloorDerecha
@onready var ray_izquierda = $RayCastFloorIzquierda

func _ready() -> void:
	add_to_group("enemigos")

func recibir_dano():
	print("¡Enemigo ", name, " ha recibido daño!")
	queue_free()

func _physics_process(_delta: float) -> void:
	if is_moving:
		return
	
	mover_aleatorio()

func mover_aleatorio():
	# Forzamos a los raycasts a actualizarse en este mismo frame
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

	for opcion in opciones:
		if opcion.ray.is_colliding():
			validas.append(opcion)

	# Si hay caminos válidos (suelo), elegimos uno al azar
	if validas.size() > 0:
		var elegida = validas.pick_random()
		
		# Calculamos el destino
		var destino = global_position + (elegida.dir * GRID_SIZE)
		
		# Le decimos que se mueva a esa posición, adaptándose a la altura del piso
		var floor_y = elegida.ray.get_collision_point().y
		destino.y = floor_y + 1.0 # +1.0 para que quede encima del cubo
		
		move_to(destino)

func move_to(target_pos: Vector3):
	is_moving = true
	var tween = create_tween()
	
	# El 0.5 es el tiempo que tarda en moverse a la siguiente casilla (velocidad)
	tween.tween_property(self, "global_position", target_pos, 0.5)
	await tween.finished
	
	# Pequeña pausa antes de volver a pensar para que el movimiento no sea errático
	#await get_tree().create_timer(0.2).timeout 
	is_moving = false
