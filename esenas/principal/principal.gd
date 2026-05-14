extends Node3D

var cubo_scene = preload("res://esenas/cubo/cubo.tscn")
var mejora_scene = preload("res://esenas/mejora/mejora.tscn")
@onready var contenedor_cubos = $Node3D
@onready var jugador = $CharacterBody3D

@onready var marker_reinicio = $Marker3D
@onready var camara = $Camera3D

@export var suavizado : float = 0.1 
@export var margen_zoom : float = 2.0
@export var zoom_minimo : float = 5.0

var ancho_laberinto = 21
var largo_laberinto = 55

var zoom_objetivo : float = 10.0 
var velocidad_zoom : float = 1.0 
var zoom_maximo : float = 30.0


func _ready() -> void:

	jugador.add_to_group("jugadores")
	
	generar_laberinto()
	
	
	jugador.position = Vector3(0, 1, 0)
	marker_reinicio.position = Vector3(0, 1, 0)
	camara.look_at(Vector3.ZERO, Vector3.UP)
	camara.size = zoom_objetivo
	
func _process(_delta: float) -> void:
	
	actualizar_camara()
	
	if Input.is_action_just_pressed(&"reset"):
		jugador.position.y = marker_reinicio.position.y
		jugador.position.x = marker_reinicio.position.x
		jugador.position.z = marker_reinicio.position.z

# --- GENERACIÓN DEL LABERINTO ---
func generar_laberinto() -> void:
	var mapa = []
	for x in range(ancho_laberinto):
		var columna = []
		for z in range(largo_laberinto):
			columna.append(false)
		mapa.append(columna)

	var stack = []
	var inicio = Vector2(1, 1) 
	mapa[inicio.x][inicio.y] = true
	stack.append(inicio)
	
	var direcciones = [Vector2(0, -2), Vector2(0, 2), Vector2(-2, 0), Vector2(2, 0)]
	
	while stack.size() > 0:
		var actual = stack.back()
		var vecinos_no_visitados = []
		
		for dir in direcciones:
			var vecino = actual + dir
			if vecino.x > 0 and vecino.x < ancho_laberinto - 1 and vecino.y > 0 and vecino.y < largo_laberinto - 1:
				if mapa[vecino.x][vecino.y] == false: 
					vecinos_no_visitados.append(dir)
		
		if vecinos_no_visitados.size() > 0:
			var direccion_elegida = vecinos_no_visitados.pick_random()
			var siguiente_casilla = actual + direccion_elegida
			var casilla_intermedia = actual + (direccion_elegida / 2) 
			
			mapa[siguiente_casilla.x][siguiente_casilla.y] = true
			mapa[casilla_intermedia.x][casilla_intermedia.y] = true
			
			stack.append(siguiente_casilla)
		else:
			stack.pop_back()


	for x in range(1, ancho_laberinto - 1):
		for z in range(1, largo_laberinto - 1):
			if mapa[x][z] == false:
				var camino_horizontal = mapa[x - 1][z] == true and mapa[x + 1][z] == true
				var camino_vertical = mapa[x][z - 1] == true and mapa[x][z + 1] == true
				

				if camino_horizontal or camino_vertical:

					if randf() < 0.15:
						mapa[x][z] = true
############### Aleatoriedad de power-ups
	var offset_x = int(ancho_laberinto / 2.0)
	var offset_z = int(largo_laberinto / 2.0)
	var altura = -1.0 

	for x in range(ancho_laberinto):
		for z in range(largo_laberinto):
			if mapa[x][z] == true:
				var pos_x = x - offset_x
				var pos_z = z - offset_z
				
				# 1. Colocar el bloque de piso
				var nuevo_cubo = cubo_scene.instantiate()
				nuevo_cubo.position = Vector3(pos_x, altura, pos_z)
				contenedor_cubos.add_child(nuevo_cubo)
				
				# MANEJAR PROBABILIDAD
				if randf() < 0.001 and not (pos_x == 0 and pos_z == 0):
					var nueva_mejora = mejora_scene.instantiate()
					#ALTURA DEL PISO 0.5
					nueva_mejora.position = Vector3(pos_x, altura + 0.5, pos_z)
					contenedor_cubos.add_child(nueva_mejora)
				
	var cubo_central = cubo_scene.instantiate()
	cubo_central.position = Vector3(0, altura, 0)
	contenedor_cubos.add_child(cubo_central)

# --- DETECCIÓN DE LA RUEDA DEL RATÓN ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_objetivo -= velocidad_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_objetivo += velocidad_zoom
		
		zoom_objetivo = clamp(zoom_objetivo, zoom_minimo, zoom_maximo)
		print(zoom_objetivo)



func actualizar_camara():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0:
		return

	# 1. Calcular el punto medio
	var centro = Vector3.ZERO
	for j in jugadores:
		centro += j.global_position
	centro /= jugadores.size()

	# 2. Mover la cámara usando la perspectiva isométrica perfecta (10, 10, 10)
	var posicion_objetivo = centro + Vector3(10, 10, 10) 
	camara.global_position = camara.global_position.lerp(posicion_objetivo, suavizado)
	
	# 3. Apuntar siempre al centro de la acción
	camara.look_at(centro, Vector3.UP)

	# 4. Calcular el Zoom
	var zoom_final = zoom_objetivo # Usamos el zoom de la ruedita por defecto
	
	
	# Pero si hay 2 o más jugadores y están muy separados, forzamos la cámara a alejarse
	if jugadores.size() > 1:
		var distancia = jugadores[0].global_position.distance_to(jugadores[1].global_position)
		zoom_final = max(zoom_objetivo, distancia + margen_zoom)
		if zoom_final > 26.0: zoom_final = 26.0

	# Aplicar el zoom suavemente
	camara.size = lerp(camara.size, zoom_final, suavizado)
