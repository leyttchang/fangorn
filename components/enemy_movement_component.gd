class_name EnemyMovementComponent
extends Node

var _parent_body: CharacterBody3D

func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D

# --- FREINAGE ---
func apply_friction(current_velocity_2d: Vector2, behavior: EnemyBehaviorData, delta: float) -> Vector2:
	if behavior == null or _parent_body == null: return current_velocity_2d
	
	var current_friction = behavior.friction if _parent_body.is_on_floor() else behavior.air_friction
	return current_velocity_2d.move_toward(Vector2.ZERO, current_friction * delta)

# --- ACCÉLÉRATION ---
func accelerate_to_direction(current_velocity_2d: Vector2, direction_3d: Vector3, speed: float, behavior: EnemyBehaviorData, delta: float) -> Vector2:
	if behavior == null: return current_velocity_2d
	
	var direction_2d = Vector2(direction_3d.x, direction_3d.z)
	var target_velocity_2d = direction_2d * speed
	return current_velocity_2d.move_toward(target_velocity_2d, behavior.acceleration * delta)

# --- ROTATION FLUIDE ---
func rotate_towards_direction(direction_3d: Vector3, behavior: EnemyBehaviorData, delta: float, speed_multiplier: float = 1.0) -> void:
	if behavior == null or _parent_body == null: return
	
	var dir_2d = Vector2(direction_3d.x, direction_3d.z)
	if dir_2d.length() > 0.1:
		var target_rotation_y = atan2(dir_2d.x, dir_2d.y) # En 2D, l'axe Y correspond à l'axe Z de la 3D
		_parent_body.rotation.y = lerp_angle(_parent_body.rotation.y, target_rotation_y, behavior.rotation_speed * speed_multiplier * delta)
