@tool
class_name MonsterPack
extends Node3D

## Contrôleur de Meute de Monstres (MonsterPack)
## Gère de petits groupes de monstres hors rencontres : Embuscades, Rôdeurs, Patrouilles.
## Compatible avec l'éditeur et le MapGenerator procédural, entièrement synchronisé en multijoueur.

enum PackRole {
	AMBUSH,  ## Embuscade : immobiles, cachés. Rayon de détection personnalisé. Se réveillent tous ensemble.
	ROAM,    ## Rôdeur : vadrouillent dans une zone (ex: forêt) avec des pauses naturelles.
	PATROL   ## Patrouille : suivent un itinéraire de waypoints en boucle ou aller-retour.
}

enum PackState {
	IDLE_WAIT,    ## Attente sur place avant prochain déplacement
	MOVING,       ## Monstres en cours de déplacement vers leurs points
	COMBAT        ## Au moins un monstre est en combat (Pack Mind actif)
}

# ==========================================================
# EXPORTS / CONFIGURATION
# ==========================================================
@export_category("Configuration du Pack")
## Rôle comportemental du pack
@export var role: PackRole = PackRole.ROAM
## Portée de détection personnalisée (si > 0, écrase celle des monstres du pack). Ex: 8m pour AMBUSH.
@export var detection_range: float = 20.0
## Portée de perte d'aggro personnalisée (si > 0)
@export var lose_aggro_range: float = 35.0
## Pack Mind : si un monstre repère un joueur ou prend des dégâts, toute la meute est alertée !
@export var aggro_link: bool = true

@export_category("Ambush Settings (Mode AMBUSH)")
## Point surveillé sur la route (déclencheur principal d'embuscade)
@export var road_ambush_point: Vector3 = Vector3.INF
## Rayon de déclenchement autour du point de la route
@export var road_trigger_radius: float = 22.0
## Direction vers la route que la meute surveille
@export var ambush_road_direction: Vector3 = Vector3.ZERO
## Distance maximale de détection en vision vers la route (en mètres)
@export var ambush_view_distance: float = 35.0
## Cône de vision vers la route (cosinus de l'angle : 0.17 = ~80° de chaque côté, soit 160° face à la route)
@export var ambush_view_fov_cos: float = 0.17
## Indique si l'embuscade a déjà été déclenchée
@export var is_ambush_triggered: bool = false
## Buff de vitesse appliqué lors de l'embuscade (80% -> 50% sur 5s, 50% sur 5-10s)
@export var ambush_status_effect: StatusEffectData = preload("res://scripts/status_effects/ambush_speed_buff.tres")

@export_category("Membres")
## Références manuelles aux monstres (si vide, détecte automatiquement les enfants CharacterBody3D !)
@export var members: Array[CharacterBody3D] = []
## Scènes optionnelles à spawner automatiquement au chargement
@export var auto_spawn_scenes: Array[PackedScene] = []

@export_category("Roam Settings (Mode ROAM)")
## Rayon de vadrouille autour du point d'apparition (en mètres)
@export var roam_radius: float = 20.0
## Pause minimale sur place une fois arrivés (en secondes)
@export var min_idle_time: float = 4.0
## Pause maximale sur place une fois arrivés (en secondes)
@export var max_idle_time: float = 9.0
## Vitesse de marche hors-combat (fraction de la vitesse max)
@export var walk_speed_multiplier: float = 0.55

@export_category("Patrol Settings (Mode PATROL)")
## Waypoints sous forme de Node3D / Marker3D (si vide, prend les Marker3D enfants)
@export var waypoints: Array[Node3D] = []
## Coordonnées 3D directes (idéal pour le MapGenerator !)
@export var waypoint_positions: Array[Vector3] = []
## Boucler (0 -> 1 -> 2 -> 0) ou aller-retour (0 -> 1 -> 2 -> 1 -> 0)
@export var loop_patrol: bool = true
## Temps d'attente à chaque waypoint (en secondes)
@export var waypoint_wait_time: float = 2.5

@export_category("Formation & Dispersion")
## Distance d'écartement minimum entre les monstres pour ne pas se superposer
@export var min_member_spread: float = 1.8
## Distance d'écartement maximum entre les monstres
@export var max_member_spread: float = 3.5
## Délai minimum de départ échelonné (désynchronisation)
@export var min_stagger_delay: float = 0.1
## Délai maximum de départ échelonné (désynchronisation)
@export var max_stagger_delay: float = 1.2

# ==========================================================
# VARIABLES INTERNES
# ==========================================================
var current_pack_state: PackState = PackState.IDLE_WAIT
var spawn_origin: Vector3 = Vector3.ZERO

var _idle_timer: float = 0.0
var _current_waypoint_index: int = 0
var _patrol_direction_forward: bool = true
var _combat_cooldown: float = 0.0
var _move_timeout: float = 0.0

# Dictionnaire des départs échelonnés en attente :
# member -> { "destination": Vector3, "speed_mult": float, "delay": float }
var _pending_dispatches: Dictionary = {}

# ==========================================================
# INITIALISATION
# ==========================================================
func _ready() -> void:
	spawn_origin = global_position
	child_entered_tree.connect(_on_child_entered_tree)
	
	# La logique IA et le pathing ne tournent QUE sur le serveur en jeu réel
	if Engine.is_editor_hint() or not multiplayer.is_server():
		return
		
	# 1. Spawner d'éventuelles scènes automatiques
	_spawn_configured_scenes()
	
	# 2. Détecter automatiquement les monstres enfants si members est vide
	if members.is_empty():
		for child in get_children():
			if child is CharacterBody3D and not members.has(child):
				add_member(child)
				
	# 3. Détecter les Marker3D enfants pour la patrouille si waypoints est vide
	if waypoints.is_empty() and waypoint_positions.is_empty():
		for child in get_children():
			if child is Marker3D:
				waypoints.append(child)
				
	# 4. Appliquer les configurations aux membres initiaux
	for member in members:
		_configure_member(member)
		
	# Délai initial aléatoire pour que différents packs sur la carte ne soient pas synchronisés
	_idle_timer = randf_range(1.0, 3.5)

func _on_child_entered_tree(node: Node) -> void:
	if not multiplayer.is_server(): return
	if node is CharacterBody3D and not members.has(node):
		add_member(node as CharacterBody3D)
	elif node is Marker3D and role == PackRole.PATROL and not waypoints.has(node):
		waypoints.append(node as Marker3D)

# ==========================================================
# API MAP GENERATOR & SCRIPTING
# ==========================================================

## Configure le pack en mode EMBUSCADE (immobile, caché derrière un arbre, guettant la route)
func setup_ambush(road_target: Vector3 = Vector3.INF, trigger_radius: float = 22.0, custom_detection: float = 8.0, look_dir: Vector3 = Vector3.ZERO) -> void:
	role = PackRole.AMBUSH
	road_ambush_point = road_target
	road_trigger_radius = trigger_radius
	detection_range = custom_detection
	is_ambush_triggered = false
	if look_dir != Vector3.ZERO:
		ambush_road_direction = look_dir.normalized()
	elif road_target.is_finite():
		ambush_road_direction = (road_target - global_position).normalized()
	_update_all_members_detection()

## Configure le pack en mode RÔDEUR (vadrouille en forêt autour du point)
func setup_roam(custom_radius: float = 20.0, custom_detection: float = 20.0) -> void:
	role = PackRole.ROAM
	roam_radius = custom_radius
	detection_range = custom_detection
	spawn_origin = global_position
	_update_all_members_detection()

## Configure le pack en mode PATROUILLE avec un itinéraire
## points peut être un Array[Vector3], Array[Vector2], ou Array[Node3D]
func setup_patrol(points: Variant, loop: bool = true, wait_time: float = 2.5) -> void:
	role = PackRole.PATROL
	loop_patrol = loop
	waypoint_wait_time = wait_time
	set_patrol_route(points, loop)

## Définit ou met à jour l'itinéraire de patrouille
func set_patrol_route(points: Variant, loop: bool = true) -> void:
	loop_patrol = loop
	waypoints.clear()
	waypoint_positions.clear()
	_current_waypoint_index = 1 if (points is Array and points.size() > 1) else 0
	_patrol_direction_forward = true
	
	if points is Array:
		for p in points:
			if p is Vector3:
				waypoint_positions.append(_project_on_navmesh(p))
			elif p is Vector2:
				# Coordonnée 2D (x, z) tirée de la route / map_generator
				var y_pos = _sample_ground_height(p.x, p.y)
				waypoint_positions.append(_project_on_navmesh(Vector3(p.x, y_pos, p.y)))
			elif p is Node3D:
				waypoints.append(p)

## Ajoute un monstre au pack
func add_member(enemy: CharacterBody3D) -> void:
	if enemy == null or members.has(enemy): return
	members.append(enemy)
	_configure_member(enemy)

## Ajoute une liste de monstres au pack
func add_members(enemy_list: Array) -> void:
	for e in enemy_list:
		if e is CharacterBody3D:
			add_member(e)

## Retire un monstre du pack
func remove_member(enemy: CharacterBody3D) -> void:
	if members.has(enemy):
		members.erase(enemy)
	if _pending_dispatches.has(enemy):
		_pending_dispatches.erase(enemy)

# ==========================================================
# BOUCLE PRINCIPALE (SERVEUR EXCLUSIF)
# ==========================================================
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not multiplayer.is_server(): return
	
	# 1. Nettoyage des membres morts ou libérés
	_cleanup_invalid_members()
	if members.is_empty():
		return
		
	# 2. Gestion du Pack Mind & de l'état de combat
	var active_combat_target = _find_active_target_in_pack()
	
	if active_combat_target != null:
		if current_pack_state != PackState.COMBAT:
			current_pack_state = PackState.COMBAT
			if role == PackRole.AMBUSH and not is_ambush_triggered:
				trigger_ambush(active_combat_target)
			elif aggro_link:
				alert_pack(active_combat_target)
		_combat_cooldown = 3.0
		return
	elif current_pack_state == PackState.COMBAT:
		# Plus aucun membre n'a de cible active
		_combat_cooldown -= delta
		if _combat_cooldown <= 0.0:
			# Combat terminé : reprise du calme
			current_pack_state = PackState.IDLE_WAIT
			_idle_timer = randf_range(2.0, 4.0)
		return
		
	# 3. Traitement des départs échelonnés (stagger delays)
	_process_pending_dispatches(delta)
	
	# 4. Machine à états hors combat
	match role:
		PackRole.AMBUSH:
			if not is_ambush_triggered:
				_process_ambush_detection()
			else:
				_process_roam_role(delta)
		PackRole.ROAM:
			_process_roam_role(delta)
		PackRole.PATROL:
			_process_patrol_role(delta)

# ==========================================================
# LOGIQUE DES RÔLES
# ==========================================================
func _process_ambush_detection() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
		
	var road_target_sq = road_trigger_radius * road_trigger_radius
	var local_det_sq = detection_range * detection_range
	var has_road_pt = road_ambush_point.is_finite()
	var has_look_dir = ambush_road_direction.length_squared() > 0.01
	var look_dir_2d = Vector2(ambush_road_direction.x, ambush_road_direction.z).normalized() if has_look_dir else Vector2.ZERO
	var view_dist_sq = ambush_view_distance * ambush_view_distance
	
	for p in players:
		if not is_instance_valid(p): continue
		if p.has_method("is_dead") and p.is_dead(): continue
		if p.get("is_dead") == true: continue
		
		var p_pos = p.global_position
		
		# 1. Déclencheur direct sur la zone de route surveillée
		if has_road_pt:
			var dist_sq_road = Vector2(p_pos.x - road_ambush_point.x, p_pos.z - road_ambush_point.z).length_squared()
			if dist_sq_road <= road_target_sq:
				trigger_ambush(p)
				return
				
		# 2. Déclencheur "Regarder spécifiquement le chemin" :
		# Détecte le joueur dans le cône ouvert (160°) faisant face à la route jusqu'à 35 mètres
		if has_look_dir:
			var to_player_2d = Vector2(p_pos.x - global_position.x, p_pos.z - global_position.z)
			var d_sq = to_player_2d.length_squared()
			if d_sq <= view_dist_sq and d_sq > 0.01:
				var dot = look_dir_2d.dot(to_player_2d.normalized())
				if dot >= ambush_view_fov_cos:
					trigger_ambush(p)
					return
					
		# 3. Déclencheur de proximité / dos (si un joueur s'approche par surprise à moins de 8m)
		var dist_sq_pack = Vector2(p_pos.x - global_position.x, p_pos.z - global_position.z).length_squared()
		if dist_sq_pack <= local_det_sq:
			trigger_ambush(p)
			return
			
		for m in members:
			if not is_instance_valid(m): continue
			var dist_sq_m = Vector2(p_pos.x - m.global_position.x, p_pos.z - m.global_position.z).length_squared()
			if dist_sq_m <= local_det_sq:
				trigger_ambush(p)
				return

## Déclenche l'embuscade : alerte toute la meute et active le buff de vitesse progressif (80% -> 50% sur 5s, 50% sur 5-10s) via StatusEffectComponent
func trigger_ambush(target_player: Node3D = null) -> void:
	if is_ambush_triggered:
		return
	is_ambush_triggered = true
	current_pack_state = PackState.COMBAT
	_combat_cooldown = 4.0
	
	if target_player == null or not is_instance_valid(target_player):
		target_player = _find_closest_player()
		
	# Restaurer une portée normale de poursuite pour tous les membres
	for member in members:
		if not is_instance_valid(member): continue
		var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
		if nav_comp:
			nav_comp.detection_range_override = -1.0
			nav_comp.lose_aggro_override = -1.0
			
	# Activer le buff de vitesse d'embuscade via StatusEffectComponent sur chaque monstre
	var effect_to_apply = ambush_status_effect
	if effect_to_apply == null:
		effect_to_apply = load("res://scripts/status_effects/ambush_speed_buff.tres") as StatusEffectData
		
	if effect_to_apply != null:
		for member in members:
			if not is_instance_valid(member): continue
			var status_comp = member.get_node_or_null("status_effect_componant")
			if status_comp != null and status_comp.has_method("apply_effect"):
				status_comp.apply_effect(effect_to_apply, 10.0)
			else:
				var stats = member.get_node_or_null("StatsComponent") as StatsComponent
				if stats:
					stats.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, 0.80, "STATUS_ambush_speed_buff")
	
	# Donner l'ordre d'attaque immédiat à tous les membres
	if target_player != null:
		alert_pack(target_player)
		print("[MonsterPack] EMBUSCADE DÉCLENCHÉE (%s) sur %s ! (Buff sprint via StatusEffect actif pour 10s)" % [
			name,
			target_player.name
		])

func _find_closest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("Player")
	var closest: Node3D = null
	var min_dist_sq: float = INF
	for p in players:
		if not is_instance_valid(p): continue
		if p.has_method("is_dead") and p.is_dead(): continue
		if p.get("is_dead") == true: continue
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist_sq:
			min_dist_sq = d
			closest = p
	return closest

func _process_roam_role(delta: float) -> void:
	match current_pack_state:
		PackState.IDLE_WAIT:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				var next_center = _pick_random_roam_point()
				dispatch_pack_to_position(next_center)
				current_pack_state = PackState.MOVING
				_move_timeout = 20.0
				
		PackState.MOVING:
			_move_timeout -= delta
			if _are_all_members_arrived() or _move_timeout <= 0.0:
				current_pack_state = PackState.IDLE_WAIT
				_idle_timer = randf_range(min_idle_time, max_idle_time)

func _process_patrol_role(delta: float) -> void:
	var total_points = _get_patrol_points_count()
	if total_points == 0:
		return
		
	match current_pack_state:
		PackState.IDLE_WAIT:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				var target_pos = _get_patrol_point_position(_current_waypoint_index)
				print("[PATROL_DISPATCH] %s -> Waypoint %d/%d : %s" % [name, _current_waypoint_index, total_points, target_pos])
				dispatch_pack_to_position(target_pos)
				current_pack_state = PackState.MOVING
				var dist = global_position.distance_to(target_pos)
				_move_timeout = maxf(45.0, dist / 0.8 + 15.0)
				
		PackState.MOVING:
			_move_timeout -= delta
			if _are_all_members_arrived() or _move_timeout <= 0.0:
				var reason = "ARRIVED" if _are_all_members_arrived() else "TIMEOUT"
				_advance_waypoint(total_points)
				current_pack_state = PackState.IDLE_WAIT
				_idle_timer = waypoint_wait_time + randf_range(-0.5, 0.5)
				print("[PATROL_ADVANCE] %s (%s) -> Prochain Waypoint %d/%d (wait: %.1fs)" % [name, reason, _current_waypoint_index, total_points, _idle_timer])

func _advance_waypoint(total_points: int) -> void:
	if total_points <= 1: return
	
	if loop_patrol:
		_current_waypoint_index = (_current_waypoint_index + 1) % total_points
	else:
		if _patrol_direction_forward:
			if _current_waypoint_index >= total_points - 1:
				_patrol_direction_forward = false
				_current_waypoint_index = total_points - 2
			else:
				_current_waypoint_index += 1
		else:
			if _current_waypoint_index <= 0:
				_patrol_direction_forward = true
				_current_waypoint_index = 1
			else:
				_current_waypoint_index -= 1

# ==========================================================
# DISPERSION / ANTI-COLLISION & STAGGER
# ==========================================================

## Envoie tous les membres du pack vers une position centrale,
## avec des décalages d'angle et de distance individuels + départs échelonnés.
func dispatch_pack_to_position(center: Vector3) -> void:
	var count = members.size()
	if count == 0: return
	
	var base_angle = randf_range(0.0, TAU)
	
	for i in range(count):
		var member = members[i]
		if not is_instance_valid(member): continue
		
		# 1. Calcul d'un décalage unique pour chaque monstre (évite toute collision)
		var angle = base_angle + (float(i) / float(count)) * TAU + randf_range(-0.3, 0.3)
		var dist = randf_range(min_member_spread, max_member_spread) if count > 1 else 0.0
		var offset = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var dest = center + offset
		
		# Projection sur le NavMesh pour s'assurer que le point est marchable
		dest = _project_on_navmesh(dest)
		
		# 2. Vitesse personnalisée avec légère variation naturelle
		var speed_mult = walk_speed_multiplier * randf_range(0.9, 1.12)
		
		# 3. Délai de départ décalé pour la désynchronisation organique
		var delay = randf_range(min_stagger_delay, max_stagger_delay) if i > 0 else 0.0
		
		_pending_dispatches[member] = {
			"destination": dest,
			"speed_mult": speed_mult,
			"delay": delay
		}

func _process_pending_dispatches(delta: float) -> void:
	var finished: Array[CharacterBody3D] = []
	for member in _pending_dispatches:
		if not is_instance_valid(member):
			finished.append(member)
			continue
			
		var data = _pending_dispatches[member]
		data["delay"] -= delta
		if data["delay"] <= 0.0:
			var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
			if nav_comp:
				nav_comp.set_pack_destination(data["destination"], data["speed_mult"])
			finished.append(member)
			
	for m in finished:
		_pending_dispatches.erase(m)

func _are_all_members_arrived() -> bool:
	if not _pending_dispatches.is_empty():
		return false
		
	for member in members:
		if not is_instance_valid(member): continue
		var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
		if nav_comp and nav_comp.has_pack_destination:
			return false
	return true

# ==========================================================
# PACK MIND / AGGRO PARTAGÉE
# ==========================================================

## Alerte toute la meute lorsqu'un joueur est repéré ou attaque
func alert_pack(target_node: Node3D) -> void:
	if target_node == null or not is_instance_valid(target_node): return
	
	_pending_dispatches.clear()
	
	for member in members:
		if not is_instance_valid(member): continue
		
		# Annuler toute destination de patrouille/roam
		var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
		if nav_comp:
			nav_comp.clear_pack_destination()
			
		# Si le monstre n'a pas encore de cible ou est en idle, lui assigner la cible
		if "target" in member:
			if member.target == null or not is_instance_valid(member.target):
				member.target = target_node
				if member.has_method("change_state"):
					# État CHASE
					var chase_state = 1
					if "State" in member and "CHASE" in member.State:
						chase_state = member.State.CHASE
					member.change_state(chase_state)

func _on_member_aggro_requested(attacker: Node3D) -> void:
	if role == PackRole.AMBUSH and not is_ambush_triggered:
		trigger_ambush(attacker)
	elif aggro_link and attacker != null:
		alert_pack(attacker)

func _find_active_target_in_pack() -> Node3D:
	for member in members:
		if not is_instance_valid(member): continue
		if "target" in member and member.target != null and is_instance_valid(member.target):
			if member.target.has_method("is_dead") and member.target.is_dead():
				member.target = null
				continue
			return member.target
	return null

# ==========================================================
# GESTION DES MEMBRES & ÉCOUTE DES SIGNAUX
# ==========================================================
func _configure_member(member: CharacterBody3D) -> void:
	if member == null or Engine.is_editor_hint(): return
	
	# Surcharge de la portée de détection
	var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
	if nav_comp:
		if role == PackRole.AMBUSH and is_ambush_triggered:
			nav_comp.detection_range_override = -1.0
			nav_comp.lose_aggro_override = -1.0
		else:
			if detection_range > 0.0:
				nav_comp.detection_range_override = detection_range
			if lose_aggro_range > 0.0:
				nav_comp.lose_aggro_override = lose_aggro_range
			
	# Écoute de prise d'aggro / coups reçus
	var hitbox = member.find_child("HitboxComponent*", true, false)
	if hitbox and hitbox.has_signal("aggro_requested"):
		if not hitbox.aggro_requested.is_connected(_on_member_aggro_requested):
			hitbox.aggro_requested.connect(_on_member_aggro_requested)
			
	# Écoute de la mort
	var health_comp = member.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_signal("died"):
		if not health_comp.died.is_connected(_on_member_died.bind(member)):
			health_comp.died.connect(_on_member_died.bind(member))

	# Optimisation automatique des performances (LOD, distance, culling d'animation)
	if not member.has_node("EnemyOptimizerComponent"):
		var opt = EnemyOptimizerComponent.new()
		opt.name = "EnemyOptimizerComponent"
		member.add_child(opt)

func _on_member_died(dead_member: CharacterBody3D) -> void:
	remove_member(dead_member)

func _update_all_members_detection() -> void:
	if Engine.is_editor_hint(): return
	for member in members:
		if not is_instance_valid(member): continue
		var nav_comp = member.get_node_or_null("EnemyNavigationComponent") as EnemyNavigationComponent
		if nav_comp:
			if role == PackRole.AMBUSH and is_ambush_triggered:
				nav_comp.detection_range_override = -1.0
				nav_comp.lose_aggro_override = -1.0
			else:
				if detection_range > 0.0:
					nav_comp.detection_range_override = detection_range
				if lose_aggro_range > 0.0:
					nav_comp.lose_aggro_override = lose_aggro_range

func _cleanup_invalid_members() -> void:
	for i in range(members.size() - 1, -1, -1):
		var m = members[i]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			members.remove_at(i)

func _spawn_configured_scenes() -> void:
	if Engine.is_editor_hint() or not multiplayer.is_server(): return
	if auto_spawn_scenes.is_empty(): return
	var parent_for_spawn = get_tree().current_scene.get_node_or_null("NetworkObjects")
	if parent_for_spawn == null:
		parent_for_spawn = self
		
	for scn in auto_spawn_scenes:
		if scn == null: continue
		var instance = scn.instantiate() as CharacterBody3D
		if instance:
			parent_for_spawn.add_child(instance, true)
			instance.global_position = global_position + Vector3(randf_range(-2.0, 2.0), 1.5, randf_range(-2.0, 2.0))
			add_member(instance)

# ==========================================================
# OUTILS GÉOMÉTRIQUES & NAVMESH
# ==========================================================
func _pick_random_roam_point() -> Vector3:
	var origin = spawn_origin if spawn_origin != Vector3.ZERO else global_position
	var angle = randf_range(0.0, TAU)
	var dist = randf_range(3.0, roam_radius)
	var candidate = origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	return _project_on_navmesh(candidate)

func _project_on_navmesh(point: Vector3) -> Vector3:
	var world_3d = get_world_3d()
	if world_3d == null: return point
	var nav_map = world_3d.navigation_map
	if not nav_map.is_valid(): return point
	
	var nav_pt = NavigationServer3D.map_get_closest_point(nav_map, point)
	if nav_pt.is_finite() and (point.length_squared() < 100.0 or nav_pt.distance_to(point) < 35.0):
		return nav_pt
	return point

func _get_patrol_points_count() -> int:
	if not waypoint_positions.is_empty():
		return waypoint_positions.size()
	return waypoints.size()

func _get_patrol_point_position(index: int) -> Vector3:
	if not waypoint_positions.is_empty():
		return waypoint_positions[clamp(index, 0, waypoint_positions.size() - 1)]
	if not waypoints.is_empty():
		var node = waypoints[clamp(index, 0, waypoints.size() - 1)]
		if is_instance_valid(node):
			return node.global_position
	return global_position

func _sample_ground_height(x: float, z: float) -> float:
	# Tente d'interroger map_generator s'il est présent dans l'arbre
	var map_gen = get_tree().get_first_node_in_group("MapGenerator")
	if map_gen == null:
		var parent = get_parent()
		if parent and parent.has_method("get_terrain_height_at"):
			map_gen = parent
	if map_gen and map_gen.has_method("get_terrain_height_at"):
		return map_gen.get_terrain_height_at(x, z)
		
	# Fallback sur l'altitude locale
	return global_position.y
