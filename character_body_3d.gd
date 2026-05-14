extends CharacterBody3D

const GRID_SIZE = 1.0 
var is_moving = false

@onready var ray_floor = $RayCastFloor

@export var player_id : int = 1 

var direccion_actual := Vector2.ZERO
func _ready() -> void:
	add_to_group("jugadores")
	
	
func _physics_process(_delta: float) -> void:
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


	if Input.is_action_just_pressed(action_up): direccion_actual = Vector2(0, -1)
	elif Input.is_action_just_pressed(action_down): direccion_actual = Vector2(0, 1)
	elif Input.is_action_just_pressed(action_left): direccion_actual = Vector2(-1, 0)
	elif Input.is_action_just_pressed(action_right): direccion_actual = Vector2(1, 0)

	var sigue_presionada = false
	if direccion_actual == Vector2(0, -1) and Input.is_action_pressed(action_up): sigue_presionada = true
	elif direccion_actual == Vector2(0, 1) and Input.is_action_pressed(action_down): sigue_presionada = true
	elif direccion_actual == Vector2(-1, 0) and Input.is_action_pressed(action_left): sigue_presionada = true
	elif direccion_actual == Vector2(1, 0) and Input.is_action_pressed(action_right): sigue_presionada = true

	# Magia del MANDO
	if not sigue_presionada:
		if abs(input_bruto.x) > abs(input_bruto.y):
			direccion_actual = Vector2(sign(input_bruto.x), 0)
		else:
			direccion_actual = Vector2(0, sign(input_bruto.y))


	if direccion_actual != Vector2.ZERO:
		var direccion_3d = Vector3(direccion_actual.x, 0, direccion_actual.y)
		var target_pos = global_position + (direccion_3d * GRID_SIZE)

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
