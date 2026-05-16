extends Control

@onready var btn_jugador = $VBoxContainer/Jugador
@onready var btn_multijugador = $VBoxContainer/Jugador2
@onready var btn_continuar = $VBoxContainer/Continuar
@onready var btn_ajustes = $VBoxContainer/Ajustes
@onready var btn_salir = $VBoxContainer/Salir

# Usaremos la escena global que ya tienes para los ajustes
var menu_ajustes = preload("res://esenas/menu_ajustes/menu_ajustes.tscn")
var ajustes_instancia: Control

func _ready() -> void:
	# Conectar señales de los botones
	btn_jugador.pressed.connect(_on_jugador_pressed)
	btn_multijugador.pressed.connect(_on_multijugador_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_ajustes.pressed.connect(_on_ajustes_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)
	
	# Si no hay partida guardada, deshabilitar el botón de continuar
	btn_continuar.disabled = not GameManager.existe_partida()

func _on_jugador_pressed() -> void:
	GameManager.nueva_partida(false) # 1 Jugador

func _on_multijugador_pressed() -> void:
	GameManager.nueva_partida(true)  # 2 Jugadores

func _on_continuar_pressed() -> void:
	GameManager.continuar_partida()

func _on_ajustes_pressed() -> void:
	if not ajustes_instancia:
		ajustes_instancia = menu_ajustes.instantiate()
		add_child(ajustes_instancia)
	ajustes_instancia.show()

func _on_salir_pressed() -> void:
	get_tree().quit()
