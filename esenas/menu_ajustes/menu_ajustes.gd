extends Control
signal menu_cerrado 

@onready var check_pantalla = $VBoxContainer/CheckPantalla
@onready var slider_musica = $VBoxContainer/SliderMusica
@onready var slider_efectos = $VBoxContainer/SliderEfectos
@onready var btn_regresar = $VBoxContainer/Regresar

var bus_musica: int
var bus_efectos: int

func _ready() -> void:
	bus_musica = AudioServer.get_bus_index("Musica")
	bus_efectos = AudioServer.get_bus_index("Efectos")
	process_mode = Node.PROCESS_MODE_ALWAYS

	btn_regresar.pressed.connect(_on_regresar_pressed)
	
	if bus_musica == -1 or bus_efectos == -1:
		push_error("¡Error! No se encontraron los buses 'Musica' o 'Efectos' en el panel de Audio.")
	
	slider_musica.value_changed.connect(_on_slider_musica_value_changed)
	slider_efectos.value_changed.connect(_on_slider_efectos_value_changed)
	
	# (Opcional) Si quieres conectar también el check de pantalla por código:
	check_pantalla.toggled.connect(_on_check_pantalla_toggled)
	# =====================================================================
	
	
	check_pantalla.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	if AudioServer.is_bus_mute(bus_musica):
		slider_musica.value = 0
	else:
		slider_musica.value = db_to_linear(AudioServer.get_bus_volume_db(bus_musica)) * 100.0
		
	if AudioServer.is_bus_mute(bus_efectos):
		slider_efectos.value = 0
	else:
		slider_efectos.value = db_to_linear(AudioServer.get_bus_volume_db(bus_efectos)) * 100.0

func _on_check_pantalla_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_slider_musica_value_changed(value: float) -> void:
	# Un print para que verifiques en la consola que la conexión funciona
	print("Slider Música movido a: ", value)
	
	if value <= 0:
		AudioServer.set_bus_mute(bus_musica, true)
	else:
		AudioServer.set_bus_mute(bus_musica, false)
		AudioServer.set_bus_volume_db(bus_musica, linear_to_db(value / 100.0))

func _on_slider_efectos_value_changed(value: float) -> void:
	# Un print para que verifiques en la consola que la conexión funciona
	print("Slider Efectos movido a: ", value)
	
	if value <= 0:
		AudioServer.set_bus_mute(bus_efectos, true)
	else:
		AudioServer.set_bus_mute(bus_efectos, false)
		AudioServer.set_bus_volume_db(bus_efectos, linear_to_db(value / 100.0))

func _on_btn_cerrar_pressed() -> void:
	hide()
func _input(event: InputEvent) -> void:
	# Si este menú está visible y presionas ESC
	if visible and event.is_action_pressed("ui_cancel"):
		# Le decimos a Godot que YA consumimos el ESC, para que no quite la pausa de golpe
		get_viewport().set_input_as_handled() 
		_cerrar_menu()

func _on_regresar_pressed() -> void:
	_cerrar_menu()

func _cerrar_menu() -> void:
	hide()
	menu_cerrado.emit() # Avisamos que nos cerramos
