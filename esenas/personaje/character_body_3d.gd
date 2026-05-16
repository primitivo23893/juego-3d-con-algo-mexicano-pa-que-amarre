extends CharacterBody3D

const GRID_SIZE = 1.0 
var is_moving = false

@onready var ray_floor = $RayCastFloor
@onready var mesh = $MeshInstance3D # Oculto en el editor
@onready var sprite = $AnimatedSprite3D # <-- NUEVA REFERENCIA AL SPRITE

@export var player_id : int = 1 
@export var color_player : StandardMaterial3D 

var direccion_actual := Vector2.ZERO
var ultima_direccion_mirada := Vector2(0, 1) 
var tiene_arma := false
var tiene_llave := false
var tiempo_caminando := 0.0
# --- VARIABLES DEL HUD ---
var tiempo_arma_restante := 0.0
const MAX_TIEMPO_ARMA := 30.0

# --- SEÑALES DE ACTUALIZACIÓN ---
signal llave_actualizada(id: int, estado: bool)
signal arma_actualizada(id: int, tiempo: float)
signal jugador_murio(id: int)

var bala_scene = preload("res://esenas/bala/bala.tscn")

func _ready() -> void:
	add_to_group("jugadores")
	if mesh:
		mesh.material_override = color_player
	
	# Sincronización inicial con la UI
	await get_tree().process_frame
	emit_signal("llave_actualizada", player_id, tiene_llave)
	emit_signal("arma_actualizada", player_id, tiempo_arma_restante)

func _process(delta: float) -> void:
	if tiene_arma:
		tiempo_arma_restante -= delta
		emit_signal("arma_actualizada", player_id, tiempo_arma_restante)
		if tiempo_arma_restante <= 0:
			perder_arma()
			
	# Pasamos el delta para que el código sepa a qué velocidad hacer el flip
	actualizar_animacion(delta)

# --- NUEVA FUNCIÓN DE ANIMACIÓN ---
func actualizar_animacion(delta: float) -> void:
	if player_id == 2: sprite = $AnimatedSprite3D2
	if not sprite: return
	
	# Usamos "walk" o "idle" según se mueva
	var estado = "walk" if is_moving else "idle"
	var animacion = ""
	
	# Velocidad a la que cambiará de pie (hará el flip). 
	# 0.1 significa que cambia cada 0.1 segundos. Puedes ajustarlo a tu gusto.
	var vel_flip = 0.1 
	
	if ultima_direccion_mirada.x > 0: # Derecha
		animacion = estado + "_side"
		sprite.flip_h = false
		tiempo_caminando = 0.0 # Reiniciamos por si cambia de eje
		
	elif ultima_direccion_mirada.x < 0: # Izquierda
		animacion = estado + "_side"
		sprite.flip_h = true
		tiempo_caminando = 0.0
		
	elif ultima_direccion_mirada.y < 0: # Arriba (Espaldas)
		animacion = estado + "_up"
		if is_moving:
			tiempo_caminando += delta
			# Matemáticas simples: alterna entre True y False rítmicamente
			sprite.flip_h = int(tiempo_caminando / vel_flip) % 2 == 0
		else:
			sprite.flip_h = false
			tiempo_caminando = 0.0
			
	else: # Abajo (Frente)
		animacion = estado + "_down"
		if is_moving:
			tiempo_caminando += delta
			sprite.flip_h = int(tiempo_caminando / vel_flip) % 2 == 0
		else:
			sprite.flip_h = false
			tiempo_caminando = 0.0
			
	# Reproducimos la animación ensamblada (ej. "walk_down")
	sprite.play(animacion)
	
func _physics_process(_delta: float) -> void:
	var action_shoot = "shoot_p" + str(player_id)
	if Input.is_action_just_pressed(action_shoot) and tiene_arma:
		disparar()

	if is_moving:
		return

	var action_up = "up_p" + str(player_id)
	var action_down = "down_p" + str(player_id)
	var action_left = "left_p" + str(player_id)
	var action_right = "right_p" + str(player_id)

	var input_bruto := Input.get_vector(action_left, action_right, action_up, action_down)

	if input_bruto == Vector2.ZERO:
		direccion_actual = Vector2.ZERO
		return

	if Input.is_action_just_pressed(action_up): 
		direccion_actual = Vector2(0, -1)
	elif Input.is_action_just_pressed(action_down): direccion_actual = Vector2(0, 1)
	elif Input.is_action_just_pressed(action_left): direccion_actual = Vector2(-1, 0)
	elif Input.is_action_just_pressed(action_right): direccion_actual = Vector2(1, 0)

	var sigue_presionada = false
	if direccion_actual == Vector2(0, -1) and Input.is_action_pressed(action_up): sigue_presionada = true
	elif direccion_actual == Vector2(0, 1) and Input.is_action_pressed(action_down): sigue_presionada = true
	elif direccion_actual == Vector2(-1, 0) and Input.is_action_pressed(action_left): sigue_presionada = true
	elif direccion_actual == Vector2(1, 0) and Input.is_action_pressed(action_right): sigue_presionada = true

	if not sigue_presionada:
		if abs(input_bruto.x) > abs(input_bruto.y):
			direccion_actual = Vector2(sign(input_bruto.x), 0)
		else:
			direccion_actual = Vector2(0, sign(input_bruto.y))

	if direccion_actual != Vector2.ZERO:
		ultima_direccion_mirada = direccion_actual
		var direccion_3d = Vector3(direccion_actual.x, 0, direccion_actual.y)
		var target_pos = global_position + (direccion_3d * GRID_SIZE)

		var escena_principal = get_tree().current_scene
		if escena_principal.has_method("es_casilla_bloqueada") and escena_principal.es_casilla_bloqueada(target_pos):
			if tiene_llave and escena_principal.has_method("abrir_puerta"):
				escena_principal.abrir_puerta(target_pos)
				tiene_llave = false 
				emit_signal("llave_actualizada", player_id, false)
				print("¡Puerta abierta por Jugador ", player_id, "!")
			return

		ray_floor.global_position = target_pos + Vector3(0, 2.0, 0)
		ray_floor.force_raycast_update()

		if ray_floor.is_colliding():
			var floor_y = ray_floor.get_collision_point().y
			target_pos.y = floor_y + 1.0 
			move_to(target_pos)
			
func move_to(target_pos: Vector3):
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.2)
	await tween.finished
	is_moving = false

func recoger_llave():
	tiene_llave = true
	emit_signal("llave_actualizada", player_id, true)
	print("¡Jugador ", player_id, " obtuvo una llave!")

func recibir_mejora(tipo: int):
	if tipo == 0: 
		tiene_arma = true
		tiempo_arma_restante = MAX_TIEMPO_ARMA
		emit_signal("arma_actualizada", player_id, tiempo_arma_restante)

func perder_arma():
	tiene_arma = false
	tiempo_arma_restante = 0.0
	emit_signal("arma_actualizada", player_id, 0.0)

func morir():
	emit_signal("jugador_murio", player_id)
	queue_free()

func disparar():
	var nueva_bala = bala_scene.instantiate()
	get_tree().current_scene.add_child(nueva_bala)
	nueva_bala.global_position = self.global_position
	
	var dir_3d = Vector3(ultima_direccion_mirada.x, 0, ultima_direccion_mirada.y)
	var rotacion_y = atan2(dir_3d.x, dir_3d.z)
	nueva_bala.rotation.y = rotacion_y + 2 * PI / 4

	if nueva_bala.has_method("configurar"):
		nueva_bala.configurar(dir_3d)

func jugador_2():
	$AnimatedSprite3D.hide()
	$AnimatedSprite3D2.show()
