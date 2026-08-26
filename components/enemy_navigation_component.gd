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
	else:
		# TRÈS IMPORTANT : On augmente la distance pour valider un point de passage.
		# Comme le sol (NavMesh) est à 1.6m sous les pieds du Scout, l'agent bloquait 
		# indéfiniment en essayant d'atteindre ce point sous terre.
		nav_agent.path_desired_distance = 3.0
		nav_agent.target_desired_distance = 3.0

# L'IA appelle juste cette fonction, le composant fait le reste !
func get_direction_to_target(target_position: Vector3) -> Vector3:
	if nav_agent == null or _parent_body == null: return Vector3.ZERO
	
	frames_since_path_update += 1
	
	if frames_since_path_update >= next_path_update_frame:
		nav_agent.target_position = target_position
		frames_since_path_update = 0
		next_path_update_frame = randi_range(20, 40)
		
	var next_path_pos = nav_agent.get_next_path_position()
	
	# On ignore la diffrence de hauteur (axe Y) pour la direction, 
	# sinon si le NavMesh est lgrement plus bas que le monstre, 
	# la direction pointe vers le bas et sa vitesse horizontale devient 0 !
	var direction = (next_path_pos - _parent_body.global_position)
	direction.y = 0.0
	
	if direction.length_squared() > 0.001:
		return direction.normalized()
	return Vector3.ZERO
