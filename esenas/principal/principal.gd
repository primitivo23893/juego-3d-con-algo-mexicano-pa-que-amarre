extends Node3D

var cubo_scene = preload("res://esenas/cubo/cubo.tscn")
var mejora_scene = preload("res://esenas/mejora/mejora.tscn")
var enemigo = preload("res://esenas/enemigo/enemigo.tscn")
var cesped_scene = preload("res://esenas/cubo/cesped.tscn") 
var puerta_scene = preload("res://esenas/cubo/puerta.tscn")
var jugador_scene = preload("res://esenas/personaje/character_body_3d.tscn") 
var menu_pausa_scene = preload("res://esenas/menu_pausa/menu_pausa.tscn")
var valla_scene = preload("res://esenas/cubo/valla.tscn")
var tumba_scene = preload("res://esenas/cubo/tumba.tscn")
var arbol_scene = preload("res://esenas/cubo/arbol.tscn")

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
var ultimo_chunk_borrado : int = -1

var zoom_objetivo : float = 10.0 
var velocidad_zoom : float = 1.0 
var zoom_maximo : float = 50.0

var casillas_puertas = {}
var posiciones_suelo_por_chunk = {}

var jugador_1: Node3D
var jugador_2: Node3D
var timer_guardado: Timer

# --- VARIABLES Y REFERENCIAS COOPERATIVAS DEL HUD ---
var bajas_globales : int = 0

@onready var ui_j1 = $CanvasLayer/MarginContainer/UI_Jugador1
@onready var llave_j1 = $CanvasLayer/MarginContainer/UI_Jugador1/Llave
@onready var label_tiempo_j1 = $CanvasLayer/MarginContainer/UI_Jugador1/LabelTiempoArmaP1

@onready var ui_j2 = $CanvasLayer/MarginContainer/UI_Jugador2
@onready var llave_j2 = $CanvasLayer/MarginContainer/UI_Jugador2/Llave if $CanvasLayer/MarginContainer/UI_Jugador2.has_node("Llave") else null
@onready var label_tiempo_j2 = $CanvasLayer/MarginContainer/UI_Jugador2/LabelTiempoArmaP2 if $CanvasLayer/MarginContainer/UI_Jugador2.has_node("LabelTiempoArmaP2") else null
@onready var arma_j1 = $CanvasLayer/MarginContainer/UI_Jugador1/ArmaP1
@onready var arma_j2 = $CanvasLayer/MarginContainer/UI_Jugador2/ArmaP2
@onready var label_bajas_global = $CanvasLayer/MarginContainer/Control/LabelBajasGlobales

func _ready() -> void:
	# 1. Instanciar Menú de Pausa
	var menu_pausa = menu_pausa_scene.instantiate()
	add_child(menu_pausa)

	# Inicializar contador de bajas cooperativas a 0
	if label_bajas_global: label_bajas_global.text = "0"

	# 2. Instanciar Jugadores Dinámicamente
	jugador_1 = jugador_scene.instantiate()
	jugador_1.player_id = 1
	jugador_1.add_to_group("jugadores")
	add_child(jugador_1)
	conectar_ui_jugador(jugador_1)
	
	if GameManager.es_multijugador:
		jugador_2 = jugador_scene.instantiate()
		jugador_2.player_id = 2
		
		jugador_2.jugador_2() # para la skin
		
		
		jugador_2.add_to_group("jugadores")
		add_child(jugador_2)
		conectar_ui_jugador(jugador_2)
		if ui_j2: ui_j2.show()
	else:
		if ui_j2: ui_j2.hide() # Desactiva el HUD del J2 si juega solo

	# 3. Cargar posiciones si es "Continuar", de lo contrario ir al inicio
	var chunk_inicial = 0
	if GameManager.cargar_partida:
		jugador_1.global_position = Vector3(GameManager.datos_guardados["p1_pos_x"], GameManager.datos_guardados["p1_pos_y"], GameManager.datos_guardados["p1_pos_z"])
		if jugador_2:
			jugador_2.global_position = Vector3(GameManager.datos_guardados["p2_pos_x"], GameManager.datos_guardados["p2_pos_y"], GameManager.datos_guardados["p2_pos_z"])
		
		chunk_inicial = floor(-jugador_1.global_position.z / largo_seccion)
		ultimo_chunk_borrado = chunk_inicial - 2
	else:
		jugador_1.global_position = Vector3(0, 1, 0)
		if jugador_2:
			jugador_2.global_position = Vector3(2, 1, 0)

	# 4. Generar mundo relativo a dónde iniciamos
	generar_seccion(chunk_inicial)
	generar_seccion(chunk_inicial + 1)
	generar_seccion(chunk_inicial + 2)
	secciones_generadas = chunk_inicial + 3 
		
	marker_reinicio.global_position = jugador_1.global_position
	camara.look_at(Vector3.ZERO, Vector3.UP)
	camara.size = zoom_objetivo

	# 5. Configurar Timer de Autoguardado (cada 30 segundos)
	timer_guardado = Timer.new()
	timer_guardado.wait_time = 30.0
	timer_guardado.autostart = true
	timer_guardado.timeout.connect(_on_timer_autoguardado_timeout)
	add_child(timer_guardado)

# --- LOGICA DE SINK DE SEÑALES ---
func conectar_ui_jugador(jugador: Node3D) -> void:
	jugador.llave_actualizada.connect(_on_jugador_llave_actualizada)
	jugador.arma_actualizada.connect(_on_jugador_arma_actualizada)
	jugador.jugador_murio.connect(_on_jugador_murio)

func registrar_baja_global() -> void:
	bajas_globales += 1
	if label_bajas_global:
		label_bajas_global.text = str(bajas_globales) # Actualiza el número limpio central

func _on_jugador_llave_actualizada(id: int, estado: bool) -> void:
	if id == 1:
		if llave_j1:
			if estado: llave_j1.show()
			else: llave_j1.hide()
	elif id == 2:
		if llave_j2:
			if estado: llave_j2.show()
			else: llave_j2.hide()

func _on_jugador_arma_actualizada(id: int, tiempo: float) -> void:
	# Convertimos a entero para eliminar decimales (ej. de 29.8 a 30)
	var tiempo_entero = int(ceil(tiempo))

	if id == 1:
		if tiempo > 0:
			if label_tiempo_j1:
				label_tiempo_j1.text = str(tiempo_entero)
				label_tiempo_j1.show()
			if arma_j1:
				arma_j1.show() # Muestra la imagen del arma
		else:
			if label_tiempo_j1: label_tiempo_j1.hide()
			if arma_j1: arma_j1.hide() # Oculta la imagen del arma al acabarse el tiempo

	elif id == 2:
		if tiempo > 0:
			if label_tiempo_j2:
				label_tiempo_j2.text = str(tiempo_entero)
				label_tiempo_j2.show()
			if arma_j2:
				arma_j2.show()
		else:
			if label_tiempo_j2: label_tiempo_j2.hide()
			if arma_j2: arma_j2.hide()

func _on_jugador_murio(id: int) -> void:
	if id == 1 and ui_j1: ui_j1.hide() # Desactiva el HUD completo del J1 al morir
	elif id == 2 and ui_j2: ui_j2.hide()

func _on_timer_autoguardado_timeout() -> void:
	var pos_p1 = jugador_1.global_position if jugador_1 else Vector3.ZERO
	var pos_p2 = jugador_2.global_position if jugador_2 else Vector3.ZERO
	GameManager.guardar_estado(pos_p1, pos_p2)

func _process(_delta: float) -> void:
	actualizar_camara()
	gestionar_generacion_infinita()
	
	if Input.is_action_just_pressed(&"reset"):
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		for j in jugadores: j.global_position = marker_reinicio.global_position

func es_casilla_bloqueada(pos: Vector3) -> bool:
	var coord = Vector2(round(pos.x), round(pos.z))
	return casillas_puertas.has(coord)

func abrir_puerta(pos: Vector3):
	var coord = Vector2(round(pos.x), round(pos.z))
	if casillas_puertas.has(coord):
		var i = casillas_puertas[coord]
		var puertas = get_tree().get_nodes_in_group("puertas_chunk_" + str(i))
		
		for p in puertas:
			# Desvinculamos la puerta de su grupo para que no la intente abrir 2 veces
			p.remove_from_group("puertas_chunk_" + str(i)) 
			
			# Llamamos a nuestra nueva función de la animación
			if p.has_method("abrir"):
				p.abrir()
			
		# Borramos las coordenadas lógicas para que el motor permita a los jugadores caminar
		var claves_a_borrar = []
		for c in casillas_puertas.keys():
			if casillas_puertas[c] == i:
				claves_a_borrar.append(c)
		for c in claves_a_borrar:
			casillas_puertas.erase(c)

func recolocar_mejora(chunk_idx: int):
	if posiciones_suelo_por_chunk.has(chunk_idx):
		var opciones = posiciones_suelo_por_chunk[chunk_idx]
		if opciones.size() > 0:
			var nueva_mejora = mejora_scene.instantiate()
			nueva_mejora.position = opciones.pick_random()
			nueva_mejora.add_to_group("chunk_" + str(chunk_idx))
			contenedor_cubos.call_deferred("add_child", nueva_mejora)

func gestionar_generacion_infinita():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0: return

	var z_mas_avanzado = 99999.0
	var jugador_lider = null
	for j in jugadores:
		if j.global_position.z < z_mas_avanzado:
			z_mas_avanzado = j.global_position.z
			jugador_lider = j

	if jugador_lider: marker_reinicio.global_position = jugador_lider.global_position

	var limite_actual = -(secciones_generadas * largo_seccion)
	if z_mas_avanzado - 80 < limite_actual: 
		generar_seccion(secciones_generadas)
		secciones_generadas += 1
		
	var chunk_minimo = 99999
	for j in jugadores:
		var chunk_j = floor(-j.global_position.z / largo_seccion)
		if chunk_j < chunk_minimo: chunk_minimo = chunk_j

	while ultimo_chunk_borrado + 1 < chunk_minimo:
		var chunk_a_borrar = ultimo_chunk_borrado + 1
		borrar_chunk_con_efecto(chunk_a_borrar)
		ultimo_chunk_borrado = chunk_a_borrar

func borrar_chunk_con_efecto(indice_chunk: int):
	if posiciones_suelo_por_chunk.has(indice_chunk):
		posiciones_suelo_por_chunk.erase(indice_chunk) 

	var bloques = get_tree().get_nodes_in_group("chunk_" + str(indice_chunk))
	for bloque in bloques:
		bloque.remove_from_group("chunk_" + str(indice_chunk))
		var mesh_inst = bloque.get_node_or_null("MeshInstance3D")
		var tween = create_tween().set_parallel(true)
		
		if mesh_inst and mesh_inst is MeshInstance3D:
			var mat = mesh_inst.material_override
			if not mat:
				if mesh_inst.mesh and mesh_inst.mesh.material: mat = mesh_inst.mesh.material.duplicate()
				else: mat = StandardMaterial3D.new()
			else: mat = mat.duplicate()
			mesh_inst.material_override = mat
			tween.tween_property(mat, "albedo_color", Color(0, 0, 0, 1), 0.8)
		
		tween.tween_property(bloque, "global_position:y", bloque.global_position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(bloque.queue_free)

func generar_seccion(indice: int) -> void:
	var mapa = []
	for x in range(ancho_laberinto):
		var columna = []
		for z in range(largo_seccion): columna.append(false)
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
				if mapa[vecino.x][vecino.y] == false: vecinos_no_visitados.append(dir)
		
		if vecinos_no_visitados.size() > 0:
			var direccion_elegida = vecinos_no_visitados.pick_random()
			var siguiente_casilla = actual + direccion_elegida
			var casilla_intermedia = actual + (direccion_elegida / 2) 
			mapa[siguiente_casilla.x][siguiente_casilla.y] = true
			mapa[casilla_intermedia.x][casilla_intermedia.y] = true
			stack.append(siguiente_casilla)
		else: stack.pop_back()

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
				if (camino_h or camino_v) and randf() < 0.05: mapa[x][z] = true

	var offset_x = 10  
	var altura = -1.0 
	var posiciones_de_suelo = []

	for x in range(ancho_laberinto):
		for z in range(largo_seccion):
			var pos_x = x - offset_x
			var pos_z = -z - (indice * largo_seccion) 

			# 1. PISO
			if mapa[x][z] == true:
				var nuevo_cubo = cubo_scene.instantiate()
				nuevo_cubo.position = Vector3(pos_x, altura, pos_z)
				nuevo_cubo.add_to_group("chunk_" + str(indice))
				contenedor_cubos.add_child(nuevo_cubo)
				if not (pos_x == 0 and pos_z == 0): posiciones_de_suelo.append(Vector3(pos_x, altura + 0.5, pos_z))
			else:
				if cesped_scene:
					var nuevo_cesped = cesped_scene.instantiate()
					nuevo_cesped.position = Vector3(pos_x, altura, pos_z)
					nuevo_cesped.add_to_group("chunk_" + str(indice)) 
					contenedor_cubos.add_child(nuevo_cesped)

			# 2. CALCULAR ZONAS DE PUERTAS PARA NO PONER VALLAS AHÍ (Las puertas miden 5 de ancho)
			var es_zona_puerta = false
			if z == largo_seccion - 1:
				for px in puertas: 
					if abs(x - px) <= 2:
						es_zona_puerta = true
			
			# 3. COLOCAR VALLAS ALREDEDOR
			var es_borde_izq = (x == 0)
			var es_borde_der = (x == ancho_laberinto - 1)
			var es_borde_final = (z == largo_seccion - 1)

			if (es_borde_izq and z > 0) or (es_borde_der and z > 0) or (es_borde_final and not es_zona_puerta):
				if valla_scene:
					var nueva_valla = valla_scene.instantiate()
					nueva_valla.position = Vector3(pos_x, altura +0.625, pos_z)
					nueva_valla.add_to_group("chunk_" + str(indice))
					
					for child in nueva_valla.get_children():
						var nombre_nodo = child.name.to_lower()
						if "esquina" in nombre_nodo or "corner" in nombre_nodo:
							child.hide()
							
					# Rotar solo los laterales
					if (es_borde_izq or es_borde_der) and not es_borde_final:
						nueva_valla.rotation_degrees.y = 90
						
					contenedor_cubos.add_child(nueva_valla)

			# 4. COLOCAR TUMBAS O ÁRBOLES EN EL INTERIOR
			elif not mapa[x][z] and z > 0:
				if randf() < 0.20: # 20% de probabilidad de que aparezca "algo"
					var objeto_a_instanciar = null
					
					# Lanzamos una moneda al aire (70% tumba, 30% árbol)
					if randf() < 0.7:
						if tumba_scene: 
							objeto_a_instanciar = tumba_scene.instantiate()
					else:
						if arbol_scene: 
							objeto_a_instanciar = arbol_scene.instantiate()
							
					# Si se eligió y cargó algo correctamente, lo colocamos
					if objeto_a_instanciar:
						# --- COMPENSACIÓN DE PIVOTE ---
						# Mantenemos el offset para que quede centrado en el bloque
						var offset_modelo = Vector3(0.5, 0, 0.5) 
						
						objeto_a_instanciar.position = Vector3(pos_x, altura + 1, pos_z) + offset_modelo
						objeto_a_instanciar.add_to_group("chunk_" + str(indice))
						
						# Rotaciones al azar para darle variedad al escenario
						var rotaciones = [0, 90, 180, 270]
						objeto_a_instanciar.rotation_degrees.y = rotaciones.pick_random() 
						
						contenedor_cubos.add_child(objeto_a_instanciar)
					
	# 5. --- AQUÍ ES DONDE SE COLOCAN LAS PUERTAS GIGANTES EXACTAMENTE EN SU LUGAR ---
	var pos_z_final_chunk = -(largo_seccion - 1) - (indice * largo_seccion)
	for px in puertas:
		if px < ancho_laberinto:
			var pos_x = px - offset_x
			var nueva_puerta = puerta_scene.instantiate()
			# Colocamos el modelo de tu puerta justo cerrando el pasillo
			nueva_puerta.position = Vector3(pos_x, altura + 1, pos_z_final_chunk)
			nueva_puerta.add_to_group("chunk_" + str(indice)) 
			nueva_puerta.add_to_group("puertas_chunk_" + str(indice))
			contenedor_cubos.add_child(nueva_puerta)
			
			# Registramos los 5 bloques como puerta para el sistema de colisiones del personaje
			for i in range(-2, 3): 
				casillas_puertas[Vector2(pos_x + i, pos_z_final_chunk)] = indice
	
	# 6. --- GENERACIÓN DE ENEMIGOS Y MEJORAS ---
	var cantidad_de_enemigos_por_seccion = min(3 + (indice * 2), 20) 
	var cantidad_mejoras_por_seccion = max(4 - (indice / 3), 1)      
	
	posiciones_de_suelo.shuffle()
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
			nuevo_enemigo.add_to_group("chunk_" + str(indice))
			nuevo_enemigo.add_to_group("enemigos_chunk_" + str(indice))
			if nuevo_enemigo.has_method("set_limites_chunk"): nuevo_enemigo.set_limites_chunk(indice, largo_seccion)
			contenedor_enemigos.add_child(nuevo_enemigo)
			
	if indice == 0:
		var cubo_central = cubo_scene.instantiate()
		cubo_central.position = Vector3(0, altura, 0)
		cubo_central.add_to_group("chunk_" + str(indice))
		contenedor_cubos.add_child(cubo_central)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_objetivo -= velocidad_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_objetivo += velocidad_zoom
		zoom_objetivo = clamp(zoom_objetivo, zoom_minimo, zoom_maximo)

func actualizar_camara():
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	if jugadores.size() == 0: return

	var centro = Vector3.ZERO
	for j in jugadores: centro += j.global_position
	centro /= jugadores.size()

	var posicion_objetivo = centro + Vector3(10, 10, 10) 
	camara.global_position = camara.global_position.lerp(posicion_objetivo, suavizado)
	camara.look_at(centro, Vector3.UP)

	var zoom_final = zoom_objetivo 
	if jugadores.size() > 1:
		var distancia = jugadores[0].global_position.distance_to(jugadores[1].global_position)
		zoom_final = max(zoom_objetivo, distancia + margen_zoom)

	camara.size = lerp(camara.size, zoom_final, suavizado)
