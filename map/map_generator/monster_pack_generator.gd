@tool
class_name MonsterPackGenerator
extends Node3D

## Générateur Procédural de Meutes de Monstres pour la Carte
## Génère des packs d'embuscades (sur la route), de patrouilles (itinéraires) et de rôdeurs (forêt).
## Applique le scaling multijoueur (nombre de monstres augmenté selon les joueurs connectés au départ).

# ==========================================================
# EXPORTS / CONFIGURATION
# ==========================================================
@export_category("Scènes & Références")
@export var pack_scene: PackedScene = preload("res://character/enemie/monster_pack/monster_pack.tscn")
## Liste des types de monstres disponibles pour composer les meutes
@export var available_monsters: Array[PackedScene] = [
	preload("res://character/enemie/dumb/dumb.tscn"),
	preload("res://character/enemie/Scout/scout.tscn"),
	preload("res://character/enemie/creep/creep.tscn"),
	preload("res://character/enemie/dumb_archer/dumb_archer.tscn"),
	preload("res://character/enemie/spider/spider_enemie.tscn")
]

@export_category("Quantités de Base (Mode Solo)")
## Nombre de meutes en embuscade le long des routes
@export var ambush_pack_count: int = 5
## Nombre de meutes en patrouille le long des routes
@export var patrol_pack_count: int = 4
## Nombre de meutes rôdeurs dans la forêt / nature
@export var roam_pack_count: int = 6

## Nombre minimum de monstres par meute (solo)
@export var min_monsters_per_pack: int = 2
## Nombre maximum de monstres par meute (solo)
@export var max_monsters_per_pack: int = 4

@export_category("Scaling Multijoueur")
## Pente d'augmentation du nombre de monstres par joueur supplémentaire au-delà du 1er.
## À 0.3333 : 1 joueur = x1.0, 4 joueurs = x2.0 (multiplié par 2 à 4 joueurs, comme demandé).
## À 0.5000 : +50% par joueur supplémentaire (1J = x1.0, 2J = x1.5, 4J = x2.5).
@export var difficulty_scale_per_extra_player: float = 0.3333
## Si activé, augmente aussi légèrement la taille des packs pour les grands groupes (ex: +1 monstre à 3+ joueurs)
@export var scale_pack_size_with_players: bool = true

@export_category("Paramètres Embuscades (AMBUSH)")
## Portée de détection courte pour surprendre les joueurs
@export var ambush_detection_range: float = 8.0
## Distance en retrait du bord de la route (en mètres, cachés sous les arbres)
@export var ambush_road_offset: float = 5.0

@export_category("Paramètres Patrouilles (PATROL)")
## Nombre d'étapes (waypoints) par patrouille de route
@export var patrol_waypoint_count: int = 4
## Temps d'attente à chaque étape
@export var patrol_wait_time: float = 2.5

@export_category("Paramètres Rôdeurs (ROAM)")
## Rayon minimum de vadrouille
@export var roam_radius_min: float = 18.0
## Rayon maximum de vadrouille
@export var roam_radius_max: float = 30.0
## Portée de détection des rôdeurs
@export var roam_detection_range: float = 20.0

@export_category("Sécurité du Terrain")
## Hauteur au-dessus du sol lors du spawn (évite de traverser le terrain ou de spawner dans la géométrie)
@export var spawn_height_offset: float = 1.5

@export_category("Actions (Éditeur)")
@export var spawn_now: bool = false:
	set(value):
		if value:
			spawn_now = false
			generate_monster_packs(0)

@export var clear_now: bool = false:
	set(value):
		if value:
			clear_now = false
			clear_monster_packs()

# ==========================================================
# VARIABLES INTERNES
# ==========================================================
var _spawned_monsters: Array[CharacterBody3D] = []
var _spawned_packs: Array[MonsterPack] = []
var _has_generated: bool = false

func _ready() -> void:
	# En jeu, on s'abonne à la fin de cuisson du terrain / NavMesh
	if not Engine.is_editor_hint():
		var map_gen = get_parent()
		if map_gen and map_gen.has_signal("terrain_ready"):
			map_gen.terrain_ready.connect(_on_terrain_ready)

func _on_terrain_ready() -> void:
	# Ne générer que sur le serveur et une seule fois
	if not multiplayer.is_server(): return
	if GameData.current_game_mode == GameData.GameMode.WAVE: return
	if _has_generated: return
	
	_has_generated = true
	var seed_to_use = GameData.current_seed
	var map_gen = get_parent()
	if seed_to_use == 0 and map_gen and "world_seed" in map_gen:
		seed_to_use = map_gen.world_seed
	generate_monster_packs(seed_to_use)

# ==========================================================
# CALCUL DU MULTIPLICATEUR MULTIJOUEUR
# ==========================================================
func get_player_count_multiplier() -> float:
	var player_count = max(1, GameData.starting_player_count)
	return 1.0 + float(player_count - 1) * difficulty_scale_per_extra_player

# ==========================================================
# GÉNÉRATION COMPLÈTE
# ==========================================================
func generate_monster_packs(pack_seed: int = 0) -> void:
	if not Engine.is_editor_hint() and not multiplayer.is_server():
		return
		
	clear_monster_packs()
	
	var valid_monsters = available_monsters.filter(func(s): return s != null)
	if valid_monsters.is_empty():
		push_warning("[MonsterPackGenerator] Aucune scène valide dans available_monsters !")
		return
	if pack_scene == null:
		push_warning("[MonsterPackGenerator] pack_scene manquant !")
		return
		
	var rng = RandomNumberGenerator.new()
	if pack_seed != 0:
		rng.seed = pack_seed + 9876
	else:
		rng.randomize()
		
	var mult = get_player_count_multiplier()
	var player_count = max(1, GameData.starting_player_count)
	print("[MonsterPackGenerator] Génération des meutes (Joueurs au départ: ", player_count, " | Multiplicateur: x", snapped(mult, 0.01), ")")
	
	# Nombre effectif de packs après scaling
	var effective_ambush = int(round(float(ambush_pack_count) * mult))
	var effective_patrol = int(round(float(patrol_pack_count) * mult))
	var effective_roam = int(round(float(roam_pack_count) * mult))
	
	# Bonus éventuel de monstres par pack pour les grands groupes (ex: 3 ou 4 joueurs)
	var extra_per_pack = (1 if player_count >= 3 else 0) if scale_pack_size_with_players else 0
	var min_m = min_monsters_per_pack + extra_per_pack
	var max_m = max_monsters_per_pack + extra_per_pack
	
	var path_gen = _get_path_generator()
	
	# 1. Génération des Embuscades sur les routes
	var actual_ambush = _spawn_ambush_packs(effective_ambush, valid_monsters, min_m, max_m, rng, path_gen)
	
	# 2. Génération des Patrouilles le long des routes
	var actual_patrol = _spawn_patrol_packs(effective_patrol, valid_monsters, min_m, max_m, rng, path_gen)
	
	# 3. Génération des Rôdeurs dans la forêt
	var actual_roam = _spawn_roam_packs(effective_roam, valid_monsters, min_m, max_m, rng, path_gen)
	
	print("[MonsterPackGenerator] Terminé ! %d meutes créées (Rôdeurs: %d, Embuscades: %d, Patrouilles: %d) | Total monstres : %d." % [
		_spawned_packs.size(),
		actual_roam,
		actual_ambush,
		actual_patrol,
		_spawned_monsters.size()
	])

# ==========================================================
# GÉNÉRATION DES EMBSUCADES (AMBUSH)
# ==========================================================
func _spawn_ambush_packs(count: int, valid_monsters: Array[PackedScene], min_m: int, max_m: int, rng: RandomNumberGenerator, path_gen: PathGenerator) -> int:
	if path_gen == null or path_gen.segments.is_empty() or count <= 0:
		return 0
		
	var segments = path_gen.segments
	var spawned_count = 0
	var attempts = 0
	var max_attempts = count * 15
	var mesh_spawner = _get_mesh_spawner()
	
	while spawned_count < count and attempts < max_attempts:
		attempts += 1
		var seg = segments[rng.randi_range(0, segments.size() - 1)]
		var start_pt: Vector2 = seg.get("start", Vector2.ZERO)
		var end_pt: Vector2 = seg.get("end", Vector2.ZERO)
		var dir = (end_pt - start_pt).normalized()
		if dir.length_squared() < 0.001:
			continue
		
		var t = rng.randf_range(0.15, 0.85)
		var road_pt_2d = start_pt.lerp(end_pt, t)
		var road_y = _get_terrain_height_at(road_pt_2d.x, road_pt_2d.y)
		var road_pos_3d = Vector3(road_pt_2d.x, road_y, road_pt_2d.y)
		
		# Recherche d'un arbre bordant ce segment de route
		var chosen_tree: Dictionary = {}
		if mesh_spawner and mesh_spawner.has_method("find_tree_near_road"):
			chosen_tree = mesh_spawner.find_tree_near_road(road_pos_3d, 10.0, 32.0)
			
		var spawn_pos: Vector3 = Vector3.ZERO
		var behind_dir_2d: Vector2 = Vector2.ZERO
		var trunk_radius: float = 1.0
		
		if not chosen_tree.is_empty():
			# Arbre trouvé : on cache la meute derrière le tronc par rapport à la route
			var trunk_pos: Vector3 = chosen_tree.get("trunk_pos", chosen_tree.get("pos", road_pos_3d))
			trunk_radius = float(chosen_tree.get("trunk_radius", 1.2))
			
			var from_road_to_tree_2d = Vector2(trunk_pos.x - road_pt_2d.x, trunk_pos.z - road_pt_2d.y)
			if from_road_to_tree_2d.length_squared() > 0.01:
				behind_dir_2d = from_road_to_tree_2d.normalized()
			else:
				var side = 1.0 if rng.randf() < 0.5 else -1.0
				behind_dir_2d = Vector2(-dir.y, dir.x) * side
				
			# On tient compte de la largeur réelle du tronc (rayon + marge de 1.2m à 1.8m)
			var dist_behind = trunk_radius + rng.randf_range(1.2, 1.8)
			var ambush_center_2d = Vector2(trunk_pos.x, trunk_pos.z) + behind_dir_2d * dist_behind
			var ground_y = _get_terrain_height_at(ambush_center_2d.x, ambush_center_2d.y)
			spawn_pos = Vector3(ambush_center_2d.x, ground_y, ambush_center_2d.y)
		else:
			# Repli si aucun arbre à proximité (clairière / plaine)
			var side = 1.0 if rng.randf() < 0.5 else -1.0
			var perp = Vector2(-dir.y, dir.x) * side
			behind_dir_2d = perp
			var half_w = float(seg.get("width", 15.0)) * 0.5
			var ambush_center_2d = road_pt_2d + perp * (half_w + ambush_road_offset + rng.randf_range(-1.0, 2.5))
			var ground_y = _get_terrain_height_at(ambush_center_2d.x, ambush_center_2d.y)
			spawn_pos = Vector3(ambush_center_2d.x, ground_y, ambush_center_2d.y)
		
		# Instanciation du contrôleur de pack
		var pack: MonsterPack = pack_scene.instantiate() as MonsterPack
		pack.name = "AmbushPack_%d" % (spawned_count + 1)
		add_child(pack)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			pack.owner = get_tree().edited_scene_root
		pack.global_position = spawn_pos
		
		# Configuration de l'embuscade avec la zone de détection centrée sur la route et orientée vers le chemin
		var look_dir_3d = (road_pos_3d - spawn_pos).normalized()
		var road_radius = maxf(float(seg.get("width", 15.0)) * 0.5 + 8.0, 22.0)
		pack.setup_ambush(road_pos_3d, road_radius, ambush_detection_range, look_dir_3d)
		_spawned_packs.append(pack)
		
		# Instanciation des monstres cachés derrière l'arbre
		var parent_for_monsters = _get_parent_for_monsters(pack)
		var mob_count = rng.randi_range(min_m, max_m)
		var lateral_dir_2d = Vector2(-behind_dir_2d.y, behind_dir_2d.x)
		
		for m_idx in range(mob_count):
			var scn = valid_monsters[rng.randi_range(0, valid_monsters.size() - 1)]
			var mob = scn.instantiate() as CharacterBody3D
			if mob == null: continue
			
			parent_for_monsters.add_child(mob, true)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				mob.owner = get_tree().edited_scene_root
				
			# Dispersion contenue dans l'ombre du tronc (largeur du tronc + petit recul)
			var lat_spread = rng.randf_range(-0.5, 0.5) * (trunk_radius + 0.4)
			var depth_spread = rng.randf_range(0.0, 1.4)
			var mob_pos_2d = Vector2(spawn_pos.x, spawn_pos.z) + (lateral_dir_2d * lat_spread) + (behind_dir_2d * depth_spread)
			
			var mx = mob_pos_2d.x
			var mz = mob_pos_2d.y
			var my = _get_terrain_height_at(mx, mz) + spawn_height_offset
			mob.global_position = Vector3(mx, my, mz)
			
			# Orienter le monstre vers la route surveillée pour qu'il guette l'arrivée des joueurs
			var look_target = Vector3(road_pos_3d.x, my, road_pos_3d.z)
			if not mob.global_position.is_equal_approx(look_target):
				mob.look_at(look_target, Vector3.UP)
				
			_spawned_monsters.append(mob)
			pack.add_member(mob)
			
		spawned_count += 1
		
	return spawned_count

# ==========================================================
# GÉNÉRATION DES PATROUILLES (PATROL)
# ==========================================================
func _spawn_patrol_packs(count: int, valid_monsters: Array[PackedScene], min_m: int, max_m: int, rng: RandomNumberGenerator, path_gen: PathGenerator) -> int:
	if path_gen == null or path_gen.segments.is_empty() or count <= 0:
		return 0
		
	var segments = path_gen.segments
	var spawned_count = 0
	var attempts = 0
	var max_attempts = count * 10
	
	while spawned_count < count and attempts < max_attempts:
		attempts += 1
		var route_3d = _build_road_patrol_route(segments, patrol_waypoint_count, rng)
		if route_3d.size() < 2:
			continue
		
		var pack: MonsterPack = pack_scene.instantiate() as MonsterPack
		pack.name = "PatrolPack_%d" % (spawned_count + 1)
		add_child(pack)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			pack.owner = get_tree().edited_scene_root
		pack.global_position = route_3d[0]
		# loop = false : patrouille en aller-retour (ping-pong 0 -> 1 -> 2 -> 1 -> 0) le long de la route
		pack.setup_patrol(route_3d, false, patrol_wait_time + rng.randf_range(-0.5, 0.5))
		_spawned_packs.append(pack)
		
		var parent_for_monsters = _get_parent_for_monsters(pack)
		var mob_count = rng.randi_range(min_m, max_m)
		for m_idx in range(mob_count):
			var scn = valid_monsters[rng.randi_range(0, valid_monsters.size() - 1)]
			var mob = scn.instantiate() as CharacterBody3D
			if mob == null: continue
			
			parent_for_monsters.add_child(mob, true)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				mob.owner = get_tree().edited_scene_root
				
			var mx = route_3d[0].x + rng.randf_range(-2.0, 2.0)
			var mz = route_3d[0].z + rng.randf_range(-2.0, 2.0)
			var my = _get_terrain_height_at(mx, mz) + spawn_height_offset
			mob.global_position = Vector3(mx, my, mz)
			_spawned_monsters.append(mob)
			pack.add_member(mob)
			
		spawned_count += 1
		
	return spawned_count

func _build_road_patrol_route(segments: Array[Dictionary], num_points: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var route_3d: Array[Vector3] = []
	if segments.is_empty(): return route_3d
	
	# Chercher une chaîne de segments continus le long de la même route
	var start_idx = rng.randi_range(0, segments.size() - 1)
	var curr_pt: Vector2 = segments[start_idx]["start"]
	var pt_y = _get_terrain_height_at(curr_pt.x, curr_pt.y)
	route_3d.append(Vector3(curr_pt.x, pt_y, curr_pt.y))
	
	var last_pt = curr_pt
	var current_idx = start_idx
	
	for step in range(num_points - 1):
		if current_idx < segments.size():
			var seg = segments[current_idx]
			var seg_start: Vector2 = seg.get("start", Vector2.ZERO)
			var seg_end: Vector2 = seg.get("end", Vector2.ZERO)
			
			# Vérifier la continuité (le segment doit être connecté au point précédent)
			if last_pt.distance_to(seg_start) <= 5.0:
				var y = _get_terrain_height_at(seg_end.x, seg_end.y)
				route_3d.append(Vector3(seg_end.x, y, seg_end.y))
				last_pt = seg_end
				current_idx += 1
			elif last_pt.distance_to(seg_end) <= 5.0:
				var y = _get_terrain_height_at(seg_start.x, seg_start.y)
				route_3d.append(Vector3(seg_start.x, y, seg_start.y))
				last_pt = seg_start
				current_idx += 1
			else:
				# Si le segment suivant appartient à une autre branche, on stoppe la chaîne ici
				break
		else:
			break
			
	return route_3d

# ==========================================================
# GÉNÉRATION DES RÔDEURS (ROAM)
# ==========================================================
func _spawn_roam_packs(count: int, valid_monsters: Array[PackedScene], min_m: int, max_m: int, rng: RandomNumberGenerator, path_gen: PathGenerator) -> int:
	if count <= 0: return 0
	
	var bounds = _get_map_bounds()
	var min_x = bounds.position.x
	var max_x = bounds.end.x
	var min_z = bounds.position.y
	var max_z = bounds.end.y
	
	var spawned_centers: Array[Vector2] = []
	var spawned_count = 0
	var attempts = 0
	var max_attempts = count * 15
	
	while spawned_count < count and attempts < max_attempts:
		attempts += 1
		var rx = rng.randf_range(min_x + 60.0, max_x - 60.0)
		var rz = rng.randf_range(min_z + 60.0, max_z - 60.0)
		var c = Vector2(rx, rz)
		
		# 1. Éviter les routes principales (rester dans la forêt)
		if path_gen != null and path_gen.is_point_on_path(c, 35.0):
			continue
			
		# 2. Éviter de se coller aux autres meutes rôdeurs
		var too_close = false
		for other in spawned_centers:
			if other.distance_squared_to(c) < (50.0 * 50.0):
				too_close = true
				break
		if too_close: continue
		
		# 3. Vérifier la pente et l'altitude (éviter les falaises et sommets infranchissables)
		var slope = _get_slope_at(rx, rz)
		if slope > 30.0: continue
		
		spawned_centers.append(c)
		var ground_y = _get_terrain_height_at(c.x, c.y)
		var spawn_pos = Vector3(c.x, ground_y, c.y)
		
		var pack: MonsterPack = pack_scene.instantiate() as MonsterPack
		pack.name = "RoamPack_%d" % (spawned_count + 1)
		add_child(pack)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			pack.owner = get_tree().edited_scene_root
		pack.global_position = spawn_pos
		pack.setup_roam(rng.randf_range(roam_radius_min, roam_radius_max), roam_detection_range)
		_spawned_packs.append(pack)
		
		var parent_for_monsters = _get_parent_for_monsters(pack)
		var mob_count = rng.randi_range(min_m, max_m)
		for m_idx in range(mob_count):
			var scn = valid_monsters[rng.randi_range(0, valid_monsters.size() - 1)]
			var mob = scn.instantiate() as CharacterBody3D
			if mob == null: continue
			
			parent_for_monsters.add_child(mob, true)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				mob.owner = get_tree().edited_scene_root
				
			var mx = spawn_pos.x + rng.randf_range(-2.5, 2.5)
			var mz = spawn_pos.z + rng.randf_range(-2.5, 2.5)
			var my = _get_terrain_height_at(mx, mz) + spawn_height_offset
			mob.global_position = Vector3(mx, my, mz)
			_spawned_monsters.append(mob)
			pack.add_member(mob)
			
		spawned_count += 1
		
	return spawned_count

# ==========================================================
# NETTOYAGE
# ==========================================================
func clear_monster_packs() -> void:
	# 1. Libérer les monstres instanciés
	for mob in _spawned_monsters:
		if is_instance_valid(mob) and not mob.is_queued_for_deletion():
			mob.queue_free()
	_spawned_monsters.clear()
	
	# 2. Libérer tous les contrôleurs de pack enregistrés
	for pack in _spawned_packs:
		if is_instance_valid(pack) and not pack.is_queued_for_deletion():
			pack.queue_free()
	_spawned_packs.clear()
	
	# 3. Libérer les enfants restants au cas où
	for child in get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
		
	_has_generated = false
	print("[MonsterPackGenerator] Toutes les meutes ont été nettoyées.")

# ==========================================================
# UTILITAIRES TERRAIN & MONDE
# ==========================================================
func _get_parent_for_monsters(pack: MonsterPack) -> Node:
	if not Engine.is_editor_hint():
		var net_obj = get_tree().current_scene.get_node_or_null("NetworkObjects")
		if net_obj != null:
			return net_obj
	return pack

func _get_path_generator() -> PathGenerator:
	var map_gen = get_parent()
	if map_gen != null:
		var pg = map_gen.find_child("path_generator", true, false)
		if pg is PathGenerator:
			return pg
	return null

func _get_mesh_spawner() -> Node:
	var map_gen = get_parent()
	if map_gen != null:
		var ms = map_gen.find_child("MeshSpawner", true, false)
		if ms == null:
			ms = map_gen.find_child("mesh_spawner", true, false)
		return ms
	return null

func _get_terrain_height_at(x: float, z: float) -> float:
	var map_gen = get_parent()
	if map_gen and map_gen.has_method("get_terrain_height_at"):
		return map_gen.get_terrain_height_at(x, z)
		
	var terrain = map_gen.find_child("Terrain3D", true, false) if map_gen else null
	if terrain and "storage" in terrain and terrain.storage:
		return terrain.storage.get_height(Vector3(x, 0, z))
	elif terrain and "data" in terrain and terrain.data:
		return terrain.data.get_height(Vector3(x, 0, z))
		
	return 0.0

func _get_slope_at(x: float, z: float) -> float:
	var h_center = _get_terrain_height_at(x, z)
	var h_x = _get_terrain_height_at(x + 2.0, z)
	var h_z = _get_terrain_height_at(x, z + 2.0)
	var dx = (h_x - h_center) / 2.0
	var dz = (h_z - h_center) / 2.0
	var slope_rad = atan(sqrt(dx * dx + dz * dz))
	return rad_to_deg(slope_rad)

func _get_map_bounds() -> Rect2:
	var map_gen = get_parent()
	var w = 1024.0
	var h = 1024.0
	if map_gen != null:
		var reg_size = float(map_gen.get("region_size")) if "region_size" in map_gen else 1024.0
		var chunks_w = float(map_gen.get("map_width_chunks")) if "map_width_chunks" in map_gen else 1.0
		var chunks_h = float(map_gen.get("map_height_chunks")) if "map_height_chunks" in map_gen else 1.0
		w = reg_size * chunks_w
		h = reg_size * chunks_h
	return Rect2(0, 0, w, h)
