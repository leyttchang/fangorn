class_name EnemyNavigationComponent
extends Node

@export var nav_agent: NavigationAgent3D

@export_category("Detection")
## Distance par défaut de détection en mode NORMAL (si non définie dans behavior)
@export var default_detection_radius: float = 25.0
## Distance par défaut de perte d'aggro en mode NORMAL (si non définie dans behavior)
@export var default_lose_aggro_radius: float = 35.0
## Surcharge de détection (utilisée par exemple par MonsterPack pour embuscade ou patrouille)
@export var detection_range_override: float = -1.0
## Surcharge de perte d'aggro
@export var lose_aggro_override: float = -1.0

# --- GESTION PACK / HORS-COMBAT ---
var pack_destination: Vector3 = Vector3.INF
var has_pack_destination: bool = false
var pack_speed_mult: float = 0.55
var current_pack_path: PackedVector3Array = PackedVector3Array()
var current_path_index: int = 0

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
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 0.5

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
			
	if detection_range_override > 0.0:
		det_range = detection_range_override
	if lose_aggro_override > 0.0:
		lose_range = lose_aggro_override
			
	var max_range = lose_range if (current_target != null and is_instance_valid(current_target)) else det_range
	if min_dist_sq <= (max_range * max_range):
		return closest
		
	return null

# L'IA appelle juste cette fonction, le composant fait le reste !
func get_direction_to_target(target_position: Vector3) -> Vector3:
	if nav_agent == null or _parent_body == null: return Vector3.ZERO
	
	frames_since_path_update += 1
	
	var my_pos = _parent_body.global_position
	var to_target_2d = Vector2(target_position.x - my_pos.x, target_position.z - my_pos.z)
	var dist_to_target = to_target_2d.length()
	
	# Priorité corps-à-corps / champ proche (<= 3.5m) :
	# Fonce directement sur la cible en ligne droite sans subir de seuil d'arrêt NavMesh !
	if dist_to_target <= 3.5:
		if dist_to_target > 0.05:
			var dir_2d = to_target_2d.normalized()
			return Vector3(dir_2d.x, 0.0, dir_2d.y)
		return Vector3.ZERO
	
	# Ne recalculer le chemin vers la cible mobile que si elle a bougé significativement (> 1.5m) ou après délai
	var target_moved = nav_agent.target_position.distance_squared_to(target_position) > 2.25
	if target_moved or frames_since_path_update >= next_path_update_frame:
		nav_agent.target_position = target_position
		frames_since_path_update = 0
		next_path_update_frame = randi_range(15, 25)
		
	if nav_agent.is_navigation_finished():
		if dist_to_target > 0.05:
			var dir_2d = to_target_2d.normalized()
			return Vector3(dir_2d.x, 0.0, dir_2d.y)
		return Vector3.ZERO
		
	var next_path_pos = nav_agent.get_next_path_position()
	var to_next_2d = Vector2(next_path_pos.x - my_pos.x, next_path_pos.z - my_pos.z)
	
	# Si le point retourné par NavAgent est sous nos pieds (index 0 non validé à cause de la hauteur Y)
	if to_next_2d.length() < 1.0:
		var p = nav_agent.get_current_navigation_path()
		var idx = nav_agent.get_current_navigation_path_index()
		if idx < p.size() - 1:
			next_path_pos = p[idx + 1]
			to_next_2d = Vector2(next_path_pos.x - my_pos.x, next_path_pos.z - my_pos.z)
			
	if to_next_2d.length_squared() > 0.001:
		var dir = to_next_2d.normalized()
		return Vector3(dir.x, 0.0, dir.y)
		
	# Fallback direct vers la cible
	if dist_to_target > 0.05:
		var dir_2d = to_target_2d.normalized()
		return Vector3(dir_2d.x, 0.0, dir_2d.y)
		
	return Vector3.ZERO

# --- CONTRÔLE DE DESTINATION DE MEUTE (HORS-COMBAT) ---
func set_pack_destination(dest: Vector3, speed_mult: float = 0.55) -> void:
	pack_destination = dest
	has_pack_destination = true
	pack_speed_mult = speed_mult
	current_pack_path.clear()
	current_path_index = 0
	if nav_agent != null:
		nav_agent.target_position = dest
	_refresh_pack_path()

func clear_pack_destination() -> void:
	has_pack_destination = false
	pack_destination = Vector3.INF
	current_pack_path.clear()
	current_path_index = 0

func _refresh_pack_path() -> void:
	if not has_pack_destination:
		return
	if _parent_body == null:
		_parent_body = get_parent() as Node3D
	if not is_instance_valid(_parent_body):
		return
		
	var world_3d = _parent_body.get_world_3d()
	if world_3d:
		var nav_map = world_3d.navigation_map
		if nav_map.is_valid():
			var p = NavigationServer3D.map_get_path(nav_map, _parent_body.global_position, pack_destination, true)
			if not p.is_empty():
				current_pack_path = p
				current_path_index = 0
				return
				
	if nav_agent != null:
		nav_agent.target_position = pack_destination
		var p = nav_agent.get_current_navigation_path()
		if not p.is_empty():
			current_pack_path = p
			current_path_index = 0

func get_pack_roam_direction() -> Vector3:
	if not has_pack_destination:
		return Vector3.ZERO
	if _parent_body == null:
		_parent_body = get_parent() as Node3D
	if not is_instance_valid(_parent_body):
		return Vector3.ZERO
		
	var my_pos = _parent_body.global_position
	var my_pos_2d = Vector2(my_pos.x, my_pos.z)
	var final_dest_2d = Vector2(pack_destination.x, pack_destination.z)
	
	# 1. Vérifie si on est arrivé à la destination finale (2.2m en 2D XZ)
	if my_pos_2d.distance_to(final_dest_2d) <= 2.2:
		clear_pack_destination()
		return Vector3.ZERO
		
	# 2. Si le chemin est vide, on tente de le rafraîchir
	if current_pack_path.is_empty():
		_refresh_pack_path()
		
	# Si le chemin reste vide (ex: NavMesh pas encore prêt ou hors carte), cap direct vers la destination
	if current_pack_path.is_empty():
		var direct_2d = final_dest_2d - my_pos_2d
		if direct_2d.length_squared() <= 4.84: # <= 2.2m
			clear_pack_destination()
			return Vector3.ZERO
		var direct_dir = direct_2d.normalized()
		return Vector3(direct_dir.x, 0.0, direct_dir.y)
		
	# 3. Progression le long des waypoints du chemin en 2D (XZ uniquement !)
	# L'index 0 est la position de départ sur le NavMesh, on avance dès qu'on s'approche en 2D (<= 2.0m)
	while current_path_index < current_pack_path.size() - 1:
		var wp = current_pack_path[current_path_index]
		var wp_2d = Vector2(wp.x, wp.z)
		if current_path_index == 0 or my_pos_2d.distance_to(wp_2d) <= 2.0:
			current_path_index += 1
		else:
			break
			
	var target_wp = current_pack_path[current_path_index]
	var to_target_2d = Vector2(target_wp.x - my_pos.x, target_wp.z - my_pos.z)
	
	# Si c'est le dernier waypoint et qu'on y est arrivé en 2D
	if current_path_index == current_pack_path.size() - 1 and to_target_2d.length() <= 2.2:
		clear_pack_destination()
		return Vector3.ZERO
		
	if to_target_2d.length_squared() > 0.001:
		var dir = to_target_2d.normalized()
		return Vector3(dir.x, 0.0, dir.y)
		
	return Vector3.ZERO
