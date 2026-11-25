class_name EnemyMovementComponent
extends Node

var _parent_body: CharacterBody3D
var _stats_comp: StatsComponent = null
var _stats_searched: bool = false

func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D

func _get_action_speed() -> float:
	if not _stats_searched and _parent_body != null:
		_stats_searched = true
		_stats_comp = _parent_body.get_node_or_null("StatsComponent") as StatsComponent
	if _stats_comp != null:
		return clampf(_stats_comp.get_stat_value("action_speed"), 0.0, 2.0)
	return 1.0

# --- FREINAGE ---
func apply_friction(current_velocity_2d: Vector2, behavior: EnemyBehaviorData, delta: float) -> Vector2:
	if behavior == null or _parent_body == null:
		return current_velocity_2d

	var current_friction: float = behavior.friction if _parent_body.is_on_floor() else behavior.air_friction
	return current_velocity_2d.move_toward(Vector2.ZERO, current_friction * delta)

# --- ACCÉLÉRATION ---
func accelerate_to_direction(current_velocity_2d: Vector2, direction_3d: Vector3, speed: float, behavior: EnemyBehaviorData, delta: float) -> Vector2:
	if behavior == null:
		return current_velocity_2d

	var direction_2d := Vector2(direction_3d.x, direction_3d.z)
	var target_velocity_2d: Vector2 = direction_2d * speed
	return current_velocity_2d.move_toward(target_velocity_2d, behavior.acceleration * delta)

# --- ROTATION FLUIDE PLAFONNÉE ---
func rotate_towards_direction(direction_3d: Vector3, behavior: EnemyBehaviorData, delta: float, speed_multiplier: float = 1.0) -> void:
	if behavior == null or _parent_body == null or not _parent_body.is_inside_tree():
		return

	var dir_2d := Vector2(direction_3d.x, direction_3d.z)
	if dir_2d.length_squared() <= 0.01:
		return

	var target_rotation_y: float = atan2(dir_2d.x, dir_2d.y)
	var current_rot: Vector3 = _parent_body.global_rotation
	var diff: float = wrapf(target_rotation_y - current_rot.y, -PI, PI)
	if absf(diff) <= 0.0005:
		return

	var action_spd: float = _get_action_speed()
	var max_turn_rad: float = deg_to_rad(maxf(30.0, behavior.max_turn_speed_deg)) * speed_multiplier * action_spd
	var proportional_rad: float = absf(diff) * behavior.rotation_speed * 1.8 * speed_multiplier * action_spd
	var step_rad: float = minf(max_turn_rad, proportional_rad) * delta

	current_rot.y = rotate_toward(current_rot.y, current_rot.y + diff, step_rad)
	_parent_body.global_rotation = current_rot
