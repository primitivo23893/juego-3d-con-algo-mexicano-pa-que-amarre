extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"reset"):
		$CharacterBody3D.position.y = $Marker3D.position.y
		$CharacterBody3D.position.x = $Marker3D.position.x
		$CharacterBody3D.position.z = $Marker3D.position.z
