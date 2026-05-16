extends Node3D # O StaticBody3D si es el que usaste

@onready var mesh_cerrada = $Gate
@onready var mesh_abierta = $GateOpen
@onready var sonido = $AbreteSesamo

var esta_abierta = false
var pos_inicial_x = 0.0

func _ready() -> void:
	mesh_cerrada.show()
	mesh_abierta.hide()
	# Guardamos la posición original para que la puerta regrese a su lugar tras temblar
	pos_inicial_x = mesh_cerrada.position.x

func abrir() -> void:
	if esta_abierta: return
	esta_abierta = true

	# 1. Reproducir sonido
	if sonido and sonido.stream:
		sonido.play()

	# 2. ANIMACIÓN DE TEMBLOR (Shake) por código usando Tweens
	var tween = create_tween()
	var tiempo = 0.05 # Velocidad del temblor
	var fuerza = 0.15 # Qué tanto se mueve a los lados
	
	# Hacemos que tiemble izquierda y derecha repetidamente
	for i in range(4):
		tween.tween_property(mesh_cerrada, "position:x", pos_inicial_x + fuerza, tiempo)
		tween.tween_property(mesh_cerrada, "position:x", pos_inicial_x - fuerza, tiempo)
	
	# La regresamos exactamente a su posición central
	tween.tween_property(mesh_cerrada, "position:x", pos_inicial_x, tiempo)
	
	# Esperamos a que la animación termine antes de cambiar el modelo
	await tween.finished

	# 3. Cambiar a la puerta abierta
	mesh_cerrada.hide()
	mesh_abierta.show()

func cerrar() -> void:
	if not esta_abierta: return
	esta_abierta = false
	# Se cierra de golpe
	mesh_abierta.hide()
	mesh_cerrada.show()

func _process(_delta: float) -> void:
	# CIERRE AUTOMÁTICO TRAS CRUZARLA
	if esta_abierta:
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		if jugadores.size() == 0: return
		
		var todos_pasaron = true
		for j in jugadores:
			# En tu juego, ir hacia adelante es ir en la Z negativa.
			# Si la posición Z del jugador es menor que la de la puerta - 1.5 metros, ya la cruzaron completamente.
			if j.global_position.z > global_position.z - 1.5: 
				todos_pasaron = false
				break
		
		# Si ya todos pasaron al nuevo chunk, se cierra a sus espaldas
		if todos_pasaron:
			cerrar()
