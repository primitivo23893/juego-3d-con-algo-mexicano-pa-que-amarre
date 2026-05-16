extends Node

var es_multijugador: bool = false
var cargar_partida: bool = false

const RUTA_GUARDADO = "user://partida_guardada.json"

# Datos en memoria que actualizaremos
var datos_guardados = {
	"es_multijugador": false,
	"p1_pos_x": 0.0, "p1_pos_y": 1.0, "p1_pos_z": 0.0,
	"p2_pos_x": 0.0, "p2_pos_y": 1.0, "p2_pos_z": 0.0
}

func nueva_partida(multi: bool) -> void:
	es_multijugador = multi
	cargar_partida = false
	get_tree().change_scene_to_file("res://esenas/principal/principal.tscn")

func continuar_partida() -> void:
	if existe_partida():
		var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
		datos_guardados = JSON.parse_string(archivo.get_as_text())
		es_multijugador = datos_guardados["es_multijugador"]
		cargar_partida = true
		get_tree().change_scene_to_file("res://esenas/principal/principal.tscn")

func guardar_estado(pos_j1: Vector3, pos_j2: Vector3) -> void:
	datos_guardados["es_multijugador"] = es_multijugador
	datos_guardados["p1_pos_x"] = pos_j1.x
	datos_guardados["p1_pos_y"] = pos_j1.y
	datos_guardados["p1_pos_z"] = pos_j1.z
	
	if es_multijugador:
		datos_guardados["p2_pos_x"] = pos_j2.x
		datos_guardados["p2_pos_y"] = pos_j2.y
		datos_guardados["p2_pos_z"] = pos_j2.z
		
	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos_guardados))
	print("Partida guardada exitosamente.")

func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)
