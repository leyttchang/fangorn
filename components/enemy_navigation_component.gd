class_name EnemyNavigationComponent
extends Node

@export var nav_agent: NavigationAgent3D

var frames_since_path_update: int = 0
var next_path_update_frame: int = 0
var _parent_body: Node3D

func _ready() -> void:
	_parent_body = get_parent() as Node3D
	# Optimisation aléatoire pour que tous les monstres ne calculent pas en même temps
	next_path_update_frame = randi_range(20, 40)
	
	if nav_agent == null:
		push_error("EnemyNavigationComponent sur " + get_parent().name + " : NavigationAgent3D manquant !")

# L'IA appelle juste cette fonction, le composant fait le reste !
func get_direction_to_target(target_position: Vector3) -> Vector3:
	if nav_agent == null or _parent_body == null: return Vector3.ZERO
	
	frames_since_path_update += 1
	
	if frames_since_path_update >= next_path_update_frame:
		nav_agent.target_position = target_position
		frames_since_path_update = 0
		next_path_update_frame = randi_range(20, 40)
		
	var next_path_pos = nav_agent.get_next_path_position()
	return (next_path_pos - _parent_body.global_position).normalized()
