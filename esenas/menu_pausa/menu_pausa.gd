extends CanvasLayer

@onready var btn_continuar = $VBoxContainer/Continuar
@onready var btn_ajustes = $VBoxContainer/Ajustes
@onready var btn_salir = $VBoxContainer/Salir

var menu_ajustes = preload("res://esenas/menu_ajustes/menu_ajustes.tscn")
var ajustes_instancia: Control

func _ready() -> void:
	# 1. ESTO ES VITAL: Le dice a este nodo que siga funcionando aunque el juego se pause
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	hide()
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_ajustes.pressed.connect(_on_ajustes_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = not visible
		get_tree().paused = visible
		
		# 2. Mostrar u ocultar el ratón según si estamos en pausa
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_continuar_pressed() -> void:
	hide()
	get_tree().paused = false
	# Volvemos a capturar el ratón para que el jugador mueva la cámara 3D
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 

func _on_ajustes_pressed() -> void:
	if not ajustes_instancia:
		ajustes_instancia = menu_ajustes.instantiate()
		add_child(ajustes_instancia)
	ajustes_instancia.show()

func _on_salir_pressed() -> void:
	# 3. CRUCIAL: Quitar la pausa antes de salir. Si no, el menú principal nacerá pausado
	get_tree().paused = false 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Dejamos el cursor visible para usar el menú
	get_tree().change_scene_to_file("res://esenas/menu_principal/menu_principal.tscn")
