extends Node3D

var cubo_scene = preload("res://esenas/cubo/cubo.tscn")
var mejora_scene = preload("res://esenas/mejora/mejora.tscn")

@onready var contenedor_cubos = $Node3D
@onready var marker_reinicio = $Marker3D
@onready var camara = $Camera3D

@export var suavizado : float = 0.1 
@export var margen_zoom : float = 2.0
@export var zoom_minimo : float = 5.0

var ancho_laberinto = 23
var largo_seccion = 63   
var secciones_generadas = 0 

var zoom_objetivo : float = 10.0 
var velocidad_zoom : float = 1.0 
var zoom_maximo : float = 50.0

func _ready() -> void:
	generar_seccion(0)
	generar_seccion(1)
	generar_seccion(2)
	secciones_generadas = 3 
	
	# Posicionar a TODOS los jugadores al inicio de forma segura
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	for j in jugadores:
		j.global_position = Vector3(0, 1, 0)
		
	marker_reinicio.global_position = Vector3(0, 1, 0)
	camara.look_at(Vector3.ZERO, Vector3.UP)
	camara.size = zoom_objetivo
	
func _process(_delta: float) -> void:
	actualizar_camara()
	gestionar_generacion_infinita()
	
	# --- BOTÓN R CORREGIDO ---
	if Input.is_action_just_pressed(&"reset"):
		print("[LOG] Boton R presionado. Reiniciando a todos los jugadores al marcador seguro.")
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		for j in jugadores:
			j.global_position = marker_reinicio.global_position

# --- EL CEREBRO DEL MAPA INFINITO ---
func gestionar_generacion_infinita():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0: return

	# 1. Buscar al jugador líder
	var z_mas_avanzado = 99999.0
	var jugador_lider = null
	for j in jugadores:
		if j.global_position.z < z_mas_avanzado:
			z_mas_avanzado = j.global_position.z
			jugador_lider = j

	# El punto de reinicio seguro ahora sigue al líder
	if jugador_lider:
		marker_reinicio.global_position = jugador_lider.global_position

	var limite_actual = -(secciones_generadas * largo_seccion)
	
	if z_mas_avanzado - 80 < limite_actual: 
		print("[LOG] Lider llego a Z=", z_mas_avanzado, ". Generando seccion: ", secciones_generadas)
		generar_seccion(secciones_generadas)
		
	
		var seccion_a_borrar = secciones_generadas - 3	
		
		
		if seccion_a_borrar >= 0:
			print("[LOG] Tramo viejo alcanzado. Intentando borrar seccion: ", seccion_a_borrar)
			
			# Calculamos dónde empieza el abismo
			var z_seguro = -((seccion_a_borrar + 1) * largo_seccion)
			print("[LOG] Z seguro calculado para teletransportar: ", z_seguro)
			# Teletransportar a rezagados ANTES de borrar el piso
			for j in jugadores:
				if j.global_position.z >= z_seguro:
					print("[LOG] ¡Jugador ", j.name, " se quedo muy atras en Z=", j.global_position.z, "! Teletransportando al lider.")
					j.global_position = marker_reinicio.global_position
			
			var bloques_viejos = get_tree().get_nodes_in_group("chunk_" + str(seccion_a_borrar))
			for bloque in bloques_viejos:
				bloque.queue_free() 
			print("[LOG] Seccion ", seccion_a_borrar, " borrada correctamente de la memoria.")

		secciones_generadas += 1

# --- GENERACIÓN DE SECCIONES ---
func generar_seccion(indice: int) -> void:
	var mapa = []
	for x in range(ancho_laberinto):
		var columna = []
		for z in range(largo_seccion):
			columna.append(false)
		mapa.append(columna)

	var stack = []
	var inicio = Vector2(11, 1) # Mitad de 21
	mapa[inicio.x][inicio.y] = true
	stack.append(inicio)
	
	var direcciones = [Vector2(0, -2), Vector2(0, 2), Vector2(-2, 0), Vector2(2, 0)]
	
	while stack.size() > 0:
		var actual = stack.back()
		var vecinos_no_visitados = []
		
		for dir in direcciones:
			var vecino = actual + dir
			if vecino.x > 0 and vecino.x < ancho_laberinto - 1 and vecino.y > 0 and vecino.y < largo_seccion - 1:
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

	var puertas = [5, 11, 17] 
	for px in puertas:
		if px < ancho_laberinto:
			mapa[px][0] = true 
			mapa[px][largo_seccion - 1] = true 

	for x in range(1, ancho_laberinto - 1):
		for z in range(1, largo_seccion - 1):
			if mapa[x][z] == false:
				var camino_h = mapa[x - 1][z] == true and mapa[x + 1][z] == true
				var camino_v = mapa[x][z - 1] == true and mapa[x][z + 1] == true
				if (camino_h or camino_v) and randf() < 0.05:
					mapa[x][z] = true

# --- CONSTRUCCIÓN FÍSICA Y MEJORAS GARANTIZADAS ---
	var offset_x = 10 
	var altura = -1.0 
	
	# 1. Creamos una lista vacía para guardar dónde hay suelo válido
	var posiciones_de_suelo = []

	for x in range(ancho_laberinto):
		for z in range(largo_seccion):
			if mapa[x][z] == true:
				var pos_x = x - offset_x
				var pos_z = -z - (indice * largo_seccion) 

				# Ponemos el bloque de piso
				var nuevo_cubo = cubo_scene.instantiate()
				nuevo_cubo.position = Vector3(pos_x, altura, pos_z)
				nuevo_cubo.add_to_group("chunk_" + str(indice))
				contenedor_cubos.add_child(nuevo_cubo)
				
				# Guardamos esta coordenada en nuestra lista (evitando el punto de inicio 0,0)
				if not (pos_x == 0 and pos_z == 0):
					posiciones_de_suelo.append(Vector3(pos_x, altura + 0.5, pos_z))
	
	# 2. COLOCACIÓN DE MEJORAS GARANTIZADAS
	# Mezclamos la lista de pisos al azar como si fuera una baraja de cartas
	posiciones_de_suelo.shuffle()
	
	# Decidimos cuántas mejoras queremos POR SECCIÓN (Ejemplo: 3)
	var cantidad_mejoras_por_seccion = 3
	
	for i in range(cantidad_mejoras_por_seccion):
		# Nos aseguramos de que haya suficientes pisos en la lista
		if i < posiciones_de_suelo.size():
			var nueva_mejora = mejora_scene.instantiate()
			# Tomamos las primeras posiciones de la baraja ya mezclada
			nueva_mejora.position = posiciones_de_suelo[i]
			nueva_mejora.add_to_group("chunk_" + str(indice))
			contenedor_cubos.add_child(nueva_mejora)
				
	# Plataforma de inicio seguro
	if indice == 0:
		var cubo_central = cubo_scene.instantiate()
		cubo_central.position = Vector3(0, altura, 0)
		cubo_central.add_to_group("chunk_" + str(indice))
		contenedor_cubos.add_child(cubo_central)
				
	if indice == 0:
		var cubo_central = cubo_scene.instantiate()
		cubo_central.position = Vector3(0, altura, 0)
		cubo_central.add_to_group("chunk_" + str(indice))
		contenedor_cubos.add_child(cubo_central)


# --- RUEDA Y CÁMARA ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_objetivo -= velocidad_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_objetivo += velocidad_zoom
		
		zoom_objetivo = clamp(zoom_objetivo, zoom_minimo, zoom_maximo)

func actualizar_camara():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0: return

	var centro = Vector3.ZERO
	for j in jugadores:
		centro += j.global_position
	centro /= jugadores.size()

	var posicion_objetivo = centro + Vector3(10, 10, 10) 
	camara.global_position = camara.global_position.lerp(posicion_objetivo, suavizado)
	camara.look_at(centro, Vector3.UP)

	var zoom_final = zoom_objetivo 
	if jugadores.size() > 1:
		var distancia = jugadores[0].global_position.distance_to(jugadores[1].global_position)
		zoom_final = max(zoom_objetivo, distancia + margen_zoom)
		#if zoom_final > 26.0: zoom_final = 26.0

	camara.size = lerp(camara.size, zoom_final, suavizado)
