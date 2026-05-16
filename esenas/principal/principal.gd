extends Node3D

var cubo_scene = preload("res://esenas/cubo/cubo.tscn")
var mejora_scene = preload("res://esenas/mejora/mejora.tscn")
var enemigo = preload("res://esenas/enemigo/enemigo.tscn")
var cesped_scene = preload("res://esenas/cubo/cesped.tscn") 

@onready var contenedor_cubos = $Mapa
@onready var marker_reinicio = $Marker3D
@onready var camara = $Camera3D
@onready var contenedor_enemigos = $Enemigos

@export var suavizado : float = 0.1 
@export var margen_zoom : float = 2.0
@export var zoom_minimo : float = 5.0

var ancho_laberinto = 23
var largo_seccion = 63   
var secciones_generadas = 0 

# --- VARIABLE NUEVA PARA RASTREAR EL BORRADO ---
var ultimo_chunk_borrado : int = -1

var zoom_objetivo : float = 10.0 
var velocidad_zoom : float = 1.0 
var zoom_maximo : float = 50.0

func _ready() -> void:
	generar_seccion(0)
	generar_seccion(1)
	generar_seccion(2)
	secciones_generadas = 3 
	
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	for j in jugadores:
		j.global_position = Vector3(0, 1, 0)
		
	marker_reinicio.global_position = Vector3(0, 1, 0)
	camara.look_at(Vector3.ZERO, Vector3.UP)
	camara.size = zoom_objetivo
	
func _process(_delta: float) -> void:
	actualizar_camara()
	gestionar_generacion_infinita()
	
	if Input.is_action_just_pressed(&"reset"):
		print("[LOG] Boton R presionado. Reiniciando a todos los jugadores al marcador seguro.")
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		for j in jugadores:
			j.global_position = marker_reinicio.global_position

# --- LOGICA DE GENERACIÓN Y BORRADO MODIFICADA ---
func gestionar_generacion_infinita():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0: return

	# 1. Buscar al jugador líder para avanzar la generación y el punto de control
	var z_mas_avanzado = 99999.0
	var jugador_lider = null
	for j in jugadores:
		if j.global_position.z < z_mas_avanzado:
			z_mas_avanzado = j.global_position.z
			jugador_lider = j

	if jugador_lider:
		marker_reinicio.global_position = jugador_lider.global_position

	# GENERACIÓN: El líder sigue activando la creación de nuevos tramos hacia adelante
	var limite_actual = -(secciones_generadas * largo_seccion)
	if z_mas_avanzado - 80 < limite_actual: 
		print("[LOG] Lider llego a Z=", z_mas_avanzado, ". Generando seccion: ", secciones_generadas)
		generar_seccion(secciones_generadas)
		secciones_generadas += 1
		
	# BORRADO SÍNCRONO: Buscamos el chunk más atrasado en el que se encuentre cualquier jugador
	var chunk_minimo = 99999
	for j in jugadores:
		# Calculamos el índice del chunk actual basándonos en la posición Z
		var chunk_j = floor(-j.global_position.z / largo_seccion)
		if chunk_j < chunk_minimo:
			chunk_minimo = chunk_j

	# Si el chunk mínimo de los jugadores es mayor que el siguiente que toca borrar,
	# significa que TODOS los jugadores ya cruzaron al siguiente chunk de manera segura.
	while ultimo_chunk_borrado + 1 < chunk_minimo:
		var chunk_a_borrar = ultimo_chunk_borrado + 1
		print("[LOG] Todos los jugadores salieron del chunk ", chunk_a_borrar, ". Desvaneciendo terreno...")
		borrar_chunk_con_efecto(chunk_a_borrar)
		ultimo_chunk_borrado = chunk_a_borrar


# --- NUEVA FUNCIÓN PARA EL EFECTO VISUAL ---
func borrar_chunk_con_efecto(indice_chunk: int):
	var bloques = get_tree().get_nodes_in_group("chunk_" + str(indice_chunk))
	
	for bloque in bloques:
		# Lo removemos de inmediato del grupo para evitar interacciones duplicadas
		bloque.remove_from_group("chunk_" + str(indice_chunk))
		
		var mesh_inst = bloque.get_node_or_null("MeshInstance3D")
		var tween = create_tween().set_parallel(true)
		
		# 1. Efecto: Oscurecer el terreno
		if mesh_inst and mesh_inst is MeshInstance3D:
			var mat = mesh_inst.material_override
			if not mat:
				# Si el mesh original ya poseía un material interno lo duplicamos, si no, creamos uno nuevo
				if mesh_inst.mesh and mesh_inst.mesh.material:
					mat = mesh_inst.mesh.material.duplicate()
				else:
					mat = StandardMaterial3D.new()
			else:
				mat = mat.duplicate()
			
			mesh_inst.material_override = mat
			# Transición del color albedo hacia el negro absoluto en 0.8 segundos
			tween.tween_property(mat, "albedo_color", Color(0, 0, 0, 1), 0.8)
		
		# 2. Efecto: "Se va" (Cae hacia el abismo y se encoge por completo)
		tween.tween_property(bloque, "global_position:y", bloque.global_position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		#tween.tween_property(bloque, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# Al terminar la animación de este bloque en particular, se libera de la escena
		tween.chain().tween_callback(bloque.queue_free)


# --- GENERACIÓN DE SECCIONES ---
func generar_seccion(indice: int) -> void:
	var mapa = []
	for x in range(ancho_laberinto):
		var columna = []
		for z in range(largo_seccion):
			columna.append(false)
		mapa.append(columna)

	var stack = []
	var inicio = Vector2(11, 1)
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

	var offset_x = 10  
	var altura = -1.0 
	var posiciones_de_suelo = []

	for x in range(ancho_laberinto):
		for z in range(largo_seccion):
			var pos_x = x - offset_x
			var pos_z = -z - (indice * largo_seccion) 

			if mapa[x][z] == true:
				var nuevo_cubo = cubo_scene.instantiate()
				nuevo_cubo.position = Vector3(pos_x, altura, pos_z)
				nuevo_cubo.add_to_group("chunk_" + str(indice))
				contenedor_cubos.add_child(nuevo_cubo)
				
				if not (pos_x == 0 and pos_z == 0):
					posiciones_de_suelo.append(Vector3(pos_x, altura + 0.5, pos_z))
			else:
				if cesped_scene:
					var nuevo_cesped = cesped_scene.instantiate()
					nuevo_cesped.position = Vector3(pos_x, altura, pos_z)
					nuevo_cesped.add_to_group("chunk_" + str(indice)) 
					contenedor_cubos.add_child(nuevo_cesped)
	
	posiciones_de_suelo.shuffle()
	var cantidad_mejoras_por_seccion = 3
	var cantidad_de_enemigos_por_seccion = 15
	
	for i in range(cantidad_mejoras_por_seccion):
		if i < posiciones_de_suelo.size():
			var nueva_mejora = mejora_scene.instantiate()
			nueva_mejora.position = posiciones_de_suelo[i]
			nueva_mejora.add_to_group("chunk_" + str(indice))
			contenedor_cubos.add_child(nueva_mejora)
			
	posiciones_de_suelo.shuffle()
	for i in range(cantidad_de_enemigos_por_seccion):
		if i < posiciones_de_suelo.size():
			var nuevo_enemigo = enemigo.instantiate()
			nuevo_enemigo.position = posiciones_de_suelo[i] + Vector3(0, 1, 0)
			# Los enemigos también se agregan al grupo del chunk para desvanecerse o caer con él
			nuevo_enemigo.add_to_group("chunk_" + str(indice))
			contenedor_enemigos.add_child(nuevo_enemigo)
			
	if indice == 0:
		var cubo_central = cubo_scene.instantiate()
		cubo_central.position = Vector3(0, altura, 0)
		cubo_central.add_to_group("chunk_" + str(indice))
		contenedor_cubos.add_child(cubo_central)

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

	camara.size = lerp(camara.size, zoom_final, suavizado)
