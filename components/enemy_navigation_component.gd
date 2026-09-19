class_name EnemyNavigationComponent
extends Node

@export var nav_agent: NavigationAgent3D

@export_category("Detection")
## Distance par défaut de détection en mode NORMAL (si non définie dans behavior)
@export var default_detection_radius: float = 25.0
## Distance par défaut de perte d'aggro en mode NORMAL (si non définie dans behavior)
@export var default_lose_aggro_radius: float = 35.0

var frames_since_path_update: int = 999
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

func acquire_target(current_target: Node3D = null) -> Node3D:
	if _parent_body == null:
		_parent_body = get_parent() as Node3D
	if not is_instance_valid(_parent_body):
		return null
		
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return null
		
	var closest: Node3D = null
	var min_dist_sq: float = INF
	var my_pos = _parent_body.global_position
	
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.has_method("is_dead") and p.is_dead():
			continue
		if p.get("is_dead") == true:
			continue
			
		var d_sq = my_pos.distance_squared_to(p.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest = p
			
	if closest == null:
		return null
		
	# Mode WAVE : traque absolue de n'importe où sur la map
	if GameData.current_game_mode == GameData.GameMode.WAVE:
		return closest
		
	# Mode NORMAL : portée de détection
	var det_range: float = default_detection_radius
	var lose_range: float = default_lose_aggro_radius
	
	if "behavior" in _parent_body and _parent_body.behavior != null:
		if "detection_range" in _parent_body.behavior and _parent_body.behavior.detection_range > 0.0:
			det_range = _parent_body.behavior.detection_range
		if "lose_aggro_range" in _parent_body.behavior and _parent_body.behavior.lose_aggro_range > 0.0:
			lose_range = _parent_body.behavior.lose_aggro_range
			
	var max_range = lose_range if (current_target != null and is_instance_valid(current_target)) else det_range
	if min_dist_sq <= (max_range * max_range):
		return closest
		
	return null

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
		
	# Fallback direct vers la cible si le NavAgent considère la cible atteinte
	# ou si aucun point suivant n'est calculé
	var direct = (target_position - _parent_body.global_position)
	direct.y = 0.0
	if direct.length_squared() > 0.001:
		return direct.normalized()
		
	return Vector3.ZERO
