extends MeshInstance3D

@export var move_speed: float = 15.0
var is_moving: bool = false
var forward_direction: Vector3 = Vector3.FORWARD

func start_moving() -> void:
	is_moving = true

func _physics_process(delta: float) -> void:
	if is_moving:
		# On utilise la direction injectee par thunder_slash.gd
		global_position += forward_direction * move_speed * delta
