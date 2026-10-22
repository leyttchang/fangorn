@tool
extends Node3D

signal terrain_ready  ## Émis quand toute la génération est terminée

@export var terrain: Terrain3D
@export var noise: FastNoiseLite
@export var path_generator: PathGenerator
@export_category("Seed / Graine du Monde")
## Graine du monde : dicte 100% de l'aléatoire de la carte (relief, routes, forêts, arbres).
## La même graine produira EXACTEMENT la même carte à chaque fois !
@export var world_seed: int = 123456

## Coche cette case pour générer une nouvelle graine au hasard et reconstruire le monde !
@export var randomize_seed_now: bool = false:
	set(value):
		randomize_seed_now = false
		world_seed = randi() % 1000000
		if Engine.is_editor_hint():
			call_deferred("generate_terrain_async")

@export_category("Dimensions")

# Taille d'une région (laisse 1024 pour Terrain3D)
@export var region_size: int = 1024
## Largeur de la carte (en nombre de chunks de 1024m, max 10 pour éviter les crashs)
@export_range(1, 10) var map_width_chunks: int = 3
## Longueur de la carte (en nombre de chunks de 1024m, max 10 pour éviter les crashs)
@export_range(1, 10) var map_height_chunks: int = 3

@export_category("Bordures du Monde")
## Largeur de la marge plate entourant la carte (en mètres). Le mur d'arbres se placera le long de cette limite.
@export var border_margin: float = 35.0

@export_category("Élévation & Relief (Méthode 3)")
## Hauteur minimale du terrain (ex: 0.0m pour les plaines de base / niveau de l'eau)
@export var min_height: float = 0.0
## Hauteur maximale atteinte par les plus hauts sommets (ex: 80.0m, 120.0m)
@export var max_height: float = 80.0
## Contraste du relief : étire le bruit pour avoir plus de noir et blanc et moins de gris (élimine la carte surélevée et crée de vraies plaines basses)
@export_range(0.5, 3.5, 0.1) var contrast: float = 1.6
## Courbe de relief : sculpte la forme du monde (plaines plates au début, montées douces, pics au sommet)
@export var height_curve: Curve

@export_category("Brouillard de Distance (Distance Fog)")
## Active le brouillard masquant la fin de distance d'affichage des arbres (350m)
@export var distance_fog_enabled: bool = true
## Distance où le brouillard commence à apparaître (en mètres)
@export var distance_fog_begin: float = 220.0
## Distance où le brouillard atteint 100% d'opacité (en mètres, calé sur les 350m des arbres)
@export var distance_fog_end: float = 350.0

## Composant ArenaGenerator (enfant de ce nœud) : gère les arènes de boss (slots Nord / Ouest / Est).
var _arena_gen: Node = null
# Composants enfants requis, résolus et vérifiés par _validate_setup()
var _mesh_spawner: Node = null
var _grass_gen: Node = null
var _border_wall: Node = null
var _encounters: Node = null
var _meteo: Node = null
var _monster_packs: Node = null

## Durée maximale d'attente de la cuisson du NavMesh avant abandon (en ms)
const NAV_BAKE_TIMEOUT_MS: int = 300000

func get_arena_generator() -> Node:
	if _arena_gen == null or not is_instance_valid(_arena_gen):
		_arena_gen = null
		for child in get_children():
			if child.has_method("select_arenas") and child.has_method("spawn_arenas"):
				_arena_gen = child
				break
	return _arena_gen

## Zones des arènes générées (utilisé par MeshSpawner pour éviter d'y placer des arbres)
func get_arena_zones() -> Array[Dictionary]:
	return get_arena_generator().get_zones()

## Contours intérieurs des arènes (utilisé par GrassGenerator pour y planter de l'herbe)
func get_arena_grass_polygons() -> Array[PackedVector2Array]:
	return get_arena_generator().arena_grass_polygons


@export_category("Actions")
## Coche cette case pour nettoyer tout le terrain !
@export var clear_terrain_now: bool = false:
	set(value):
		clear_terrain_now = false
		clear_terrain()

## Coche cette case dans l'inspecteur pour générer !
@export var generate_now: bool = false:
	set(value):
		generate_now = false
		if Engine.is_editor_hint():
			call_deferred("generate_terrain_async")

func _ready() -> void:
	_setup_distance_fog()
	if not Engine.is_editor_hint():
		if is_standalone_scene():
			GameData.current_game_mode = GameData.GameMode.NORMAL
		else:
			# Ne détruire la caméra spectateur que si on est dans le vrai jeu (ex: sous game.tscn)
			var spectator_cam: Node = get_node_or_null("Camera3D")
			if spectator_cam != null:
				spectator_cam.queue_free()
			
		call_deferred("generate_terrain_async")

func is_standalone_scene() -> bool:
	return get_tree().current_scene == self
		
func clear_terrain() -> void:
	if not _validate_setup():
		push_error("MapGenerator: nettoyage annulé (configuration incomplète).")
		return
	var time_start = Time.get_ticks_msec()
	print("Nettoyage radical du terrain...")
	
	# Retire TOUTES les régions Terrain3D en mémoire (carte principale + extensions sous les arènes).
	# Aucun fichier n'est touché sur le disque.
	var terrain_data: Terrain3DData = terrain.data
	for region: Terrain3DRegion in terrain_data.get_regions_active():
		terrain_data.remove_region(region, false)
	terrain_data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	
	_mesh_spawner.clear_trees()
	_grass_gen.clear_grass()
	_encounters.clear_encounters()
	_monster_packs.clear_monster_packs()
	_border_wall.clear_wall()

	var existing_occ = find_child("TerrainOccluder", true, false)
	if existing_occ != null:
		existing_occ.queue_free()
		
	# Nettoyer toutes les arènes
	get_arena_generator().clear_arenas()
			
	var time_clean = Time.get_ticks_msec() - time_start
	print("Terrain nettoyé en ", time_clean, " ms !")

func get_spawn_point() -> Vector3:
	if path_generator.start_pos == Vector2.ZERO:
		push_error("MapGenerator: get_spawn_point() appelé avant la génération du chemin (start_pos non défini).")
		return Vector3.ZERO
	var p2: Vector2 = path_generator.start_pos
	return Vector3(p2.x, get_terrain_height_at(p2.x, p2.y), p2.y)

func _place_encounter_markers() -> void:
	# Nettoyer l'existant
	for child in _encounters.get_children():
		_encounters.remove_child(child)
		child.queue_free()
		
	var positions: Array = path_generator.encounter_positions
	var placed: int = 0
	for i in range(positions.size()):
		var pos2d: Vector2 = positions[i]
		
		# Hauteur sur le terrain
		var ground_y: float = terrain.data.get_height(Vector3(pos2d.x, 0.0, pos2d.y))
		if is_nan(ground_y):
			push_error("MapGenerator: hauteur de terrain introuvable pour l'encounter %d en %s, marker ignoré." % [i + 1, pos2d])
			continue
			
		var marker = Marker3D.new()
		marker.name = "encounter_" + str(i + 1)
		marker.position = Vector3(pos2d.x, ground_y, pos2d.y)
		
		_encounters.add_child(marker)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			marker.owner = get_tree().edited_scene_root
		placed += 1
			
	print("Markers d'Encounters placés : ", placed)
	_encounters.call_deferred("spawn_encounters", world_seed)

func _get_map_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(map_width_chunks * region_size), float(map_height_chunks * region_size))


## Hauteur réelle du Terrain3D (NaN si aucune donnée de terrain à cet endroit)
func _sample_edge_height(x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0.0, z))


## Hauteur du relief généré (bruit + contraste + courbe) avec la marge de bordure plate, exactement comme
## à la génération des chunks. C'est la source de hauteur AVANT que Terrain3D n'ait des données
## (utilisée par le PathGenerator pour le calcul des routes).
func get_base_height_at(gx: float, gz: float) -> float:
	var rect: Rect2 = _get_map_rect()
	var sx: float = clampf(gx, border_margin, rect.end.x - border_margin)
	var sz: float = clampf(gz, border_margin, rect.end.y - border_margin)
	var n: float = noise.get_noise_2d(sx, sz) * 0.5 + 0.5
	var t_contrasted: float = clampf((n - 0.5) * contrast + 0.5, 0.0, 1.0)
	return lerpf(min_height, max_height, height_curve.sample_baked(t_contrasted))

## Hauteur du sol en un point monde : Terrain3D dans la map, prolongement lisse du bord en dehors (sous l'arène)
func get_terrain_height_at(x: float, z: float) -> float:
	var rect: Rect2 = _get_map_rect()
	if x < rect.position.x or x >= rect.end.x or z < rect.position.y or z >= rect.end.y:
		return get_arena_generator().get_arena_ground_height(x, z)
	var h: float = _sample_edge_height(x, z)
	if is_nan(h):
		return get_arena_generator().get_arena_ground_height(x, z)
	return h

## Vérifie que tout ce dont la génération a besoin est bien en place (exports + nœuds enfants).
## Chaque élément manquant est signalé par un push_error explicite ; la génération est annulée si quoi que ce soit manque.
func _validate_setup() -> bool:
	var missing: Array[String] = []
	if terrain == null:
		missing.append("export 'terrain' (Terrain3D)")
	elif terrain.data == null:
		missing.append("Terrain3D.data")
	elif terrain.assets == null or terrain.assets.get_texture_count() < 2:
		missing.append("Terrain3D.assets : il faut au moins 2 textures (la route utilise la texture ID 1, sinon elle apparaît noire)")
	if noise == null:
		missing.append("export 'noise' (FastNoiseLite)")
	if height_curve == null:
		missing.append("export 'height_curve' (Curve)")
	if path_generator == null:
		missing.append("export 'path_generator'")
	
	_mesh_spawner = get_node_or_null("MeshSpawner")
	_grass_gen = get_node_or_null("grass_generator")
	_border_wall = get_node_or_null("BorderTreeWall")
	_encounters = get_node_or_null("Encounters")
	_meteo = get_node_or_null("Meteo")
	_monster_packs = get_node_or_null("MonsterPackGenerator")
	if _mesh_spawner == null: missing.append("nœud enfant 'MeshSpawner'")
	if _grass_gen == null: missing.append("nœud enfant 'grass_generator'")
	if _border_wall == null: missing.append("nœud enfant 'BorderTreeWall'")
	if _encounters == null: missing.append("nœud enfant 'Encounters'")
	if _meteo == null: missing.append("nœud enfant 'Meteo'")
	if _monster_packs == null: missing.append("nœud enfant 'MonsterPackGenerator'")
	if get_arena_generator() == null:
		missing.append("nœud enfant 'ArenaGenerator'")
	
	for m in missing:
		push_error("MapGenerator: élément requis manquant -> " + m)
	return missing.is_empty()

# Génération asynchrone pour ne JAMAIS faire crasher l'éditeur Godot !
func generate_terrain_async() -> void:
	if not _validate_setup():
		push_error("MapGenerator: génération annulée (configuration incomplète).")
		return
		
	print("Début de la génération du terrain (Seed: ", world_seed, ")...")
	# Applique la seed sur le bruit de relief du terrain
	noise.seed = world_seed
	clear_terrain()
	
	var arena_gen: Node = get_arena_generator()
	# Tirage au hasard d'UNE arène par slot (Nord / Ouest / Est) : doit précéder la génération des routes
	arena_gen.select_arenas(world_seed)
	
	# Pause d'une frame pour laisser Godot respirer après le nettoyage
	await get_tree().process_frame
	
	var terrain_data: Terrain3DData = terrain.data
	
	var map_min_x = 0.0
	var map_max_x = float(map_width_chunks * region_size)
	var map_min_z = 0.0
	var map_max_z = float(map_height_chunks * region_size)
	
	var total_w: int = map_width_chunks * region_size
	var total_h: int = map_height_chunks * region_size
	
	path_generator.generate_branching_path(map_min_x, map_max_x, map_min_z, map_max_z, world_seed)

	# Initialisation des sols plats pour toutes les arènes actives (Nord, Ouest, Est, etc.)
	var active_curve: Curve = height_curve
	arena_gen.init_zones()
		
	var chunks_generated: int = 0
	var ctrl_default: int = ((0 & 0x1F) << 27) | ((1 & 0x1F) << 22) | (1 << 1)
	var h_smooth_radius: float = maxf(1.0, path_generator.path_width * 0.3)
	
	var time_chunks_start = Time.get_ticks_msec()
	for cx in range(map_width_chunks):
		for cz in range(map_height_chunks):
			
			print("Génération du chunk (", cx, ", ", cz, ")...")
			var time_start: int = Time.get_ticks_msec()
			
			var chunk_min_x: int = cx * region_size
			var chunk_max_x: int = chunk_min_x + region_size
			var chunk_min_z: int = cz * region_size
			var chunk_max_z: int = chunk_min_z + region_size
			
			# Pré-filtre des segments touchant ce chunk
			var chunk_segments: Array = []
			for seg in path_generator.segments:
				var w: float = seg.width + 10.0
				if not (chunk_max_x < seg.min_x - w or chunk_min_x > seg.max_x + w or chunk_max_z < seg.min_y - w or chunk_min_z > seg.max_y + w):
					chunk_segments.append(seg)
			var seg_count: int = chunk_segments.size()
			# ===== PHASE 1 : Rasterisation des chemins (segment-first) =====
			var path_blend_array: PackedFloat32Array = PackedFloat32Array()
			path_blend_array.resize(region_size * region_size)
			
			for seg in chunk_segments:
				var seg_w: float = seg.width
				var seg_w_sq: float = seg_w * seg_w
				
				# Bbox du segment dans l'espace local du chunk
				var bx_min: int = maxi(0, int(seg.min_x) - chunk_min_x - int(seg_w) - 2)
				var bx_max: int = mini(region_size - 1, int(seg.max_x) - chunk_min_x + int(seg_w) + 2)
				var bz_min: int = maxi(0, int(seg.min_y) - chunk_min_z - int(seg_w) - 2)
				var bz_max: int = mini(region_size - 1, int(seg.max_y) - chunk_min_z + int(seg_w) + 2)
				
				if bx_min > bx_max or bz_min > bz_max:
					continue
				
				var ax: float = seg.start.x; var ay: float = seg.start.y
				var bx_s: float = seg.end.x;  var by_s: float = seg.end.y
				var ddx: float = bx_s - ax;   var ddy: float = by_s - ay
				var l2: float = ddx * ddx + ddy * ddy
				
				for lz in range(bz_min, bz_max + 1):
					var gz: float = float(chunk_min_z + lz)
					for lx in range(bx_min, bx_max + 1):
						var gx: float = float(chunk_min_x + lx)
						
						var dist_sq: float
						if l2 < 0.0001:
							var dx: float = gx - ax; var dy: float = gz - ay
							dist_sq = dx * dx + dy * dy
						else:
							var t_proj: float = maxf(0.0, minf(1.0, ((gx - ax) * ddx + (gz - ay) * ddy) / l2))
							var proj_x: float = ax + t_proj * ddx
							var proj_y: float = ay + t_proj * ddy
							var dx: float = gx - proj_x; var dy: float = gz - proj_y
							dist_sq = dx * dx + dy * dy
							
						if dist_sq < seg_w_sq:
							var dist: float = sqrt(dist_sq)
							var t_val: float = dist / seg_w
							var blend: float = 1.0 - (t_val * t_val * (3.0 - 2.0 * t_val))
							var array_idx: int = lz * region_size + lx
							if blend > path_blend_array[array_idx]:
								path_blend_array[array_idx] = blend
			
			# ===== PHASE 2 : Application du relief et de la texture =====
			var height_bytes: PackedByteArray = PackedByteArray()
			var ctrl_bytes: PackedByteArray = PackedByteArray()
			height_bytes.resize(region_size * region_size * 4)
			ctrl_bytes.resize(region_size * region_size * 4)
			
			var idx: int = 0
			for lz in range(region_size):
				var global_z = chunk_min_z + lz
				var gz: float = float(global_z)
				for lx in range(region_size):
					var global_x = chunk_min_x + lx
					var gx: float = float(global_x)
					
					# Marge plate aux bords de la map
					var margin: float = border_margin
					var safe_gx = clampf(gx, margin, float(total_w) - margin)
					var safe_gz = clampf(gz, margin, float(total_h) - margin)
					
					var n: float = noise.get_noise_2d(safe_gx, safe_gz) * 0.5 + 0.5
					var t_contrasted: float = clampf((n - 0.5) * contrast + 0.5, 0.0, 1.0)
					var h: float = lerp(min_height, max_height, active_curve.sample_baked(t_contrasted))
					
					var blend: float = path_blend_array[idx]
					if blend > 0.0:
						var nf: float = (
							noise.get_noise_2d(safe_gx + h_smooth_radius, safe_gz) +
							noise.get_noise_2d(safe_gx - h_smooth_radius, safe_gz) +
							noise.get_noise_2d(safe_gx, safe_gz + h_smooth_radius) +
							noise.get_noise_2d(safe_gx, safe_gz - h_smooth_radius)
						) * 0.125 + 0.5
						var tf: float = clampf((nf - 0.5) * contrast + 0.5, 0.0, 1.0)
						var hf: float = lerp(min_height, max_height, active_curve.sample_baked(tf))
						h = lerp(h, hf, blend)
						height_bytes.encode_float(idx * 4, h)
						var blend_byte: int = int(blend * 255.0)
						ctrl_bytes.encode_u32(idx * 4, ((0 & 0x1F) << 27) | ((1 & 0x1F) << 22) | ((blend_byte & 0xFF) << 14) | (1 << 1))
					else:
						height_bytes.encode_float(idx * 4, h)
						ctrl_bytes.encode_u32(idx * 4, ctrl_default)
					
					idx += 1
			
			var time_end: int = Time.get_ticks_msec()
			print("Chunk ", cx, ",", cz, " calculé en ", (time_end - time_start), " ms (Segments: ", seg_count, ")")
			
			var img: Image = Image.create_from_data(region_size, region_size, false, Image.FORMAT_RF, height_bytes)
			var control_img: Image = Image.create_from_data(region_size, region_size, false, Image.FORMAT_RF, ctrl_bytes)
			var chunk_pos: Vector3 = Vector3(chunk_min_x, 0, chunk_min_z)
			
			terrain_data.import_images([img, control_img, null], chunk_pos, 0.0, 1.0)
			chunks_generated += 1
			
			await get_tree().process_frame
	
	var time_chunks_total = Time.get_ticks_msec() - time_chunks_start
	print("Génération terminée ! ", chunks_generated, " chunks créés en ", time_chunks_total, " ms.")
	# Génération de la météo via le nœud dédié
	_meteo.generate_weather(world_seed)
	
	_setup_distance_fog()
	
	# Placement des points d'intérêt (Encounters)
	_place_encounter_markers()
	
	# Placement et génération de toutes les arènes configurées
	arena_gen.spawn_arenas()
	
	# Génère automatiquement le mur d'arbres de bordure
	_border_wall.call_deferred("generate_wall")
		
	# Génère automatiquement les arbres (le NavMesh est cuit une fois les arbres prêts)
	if not _mesh_spawner.trees_ready.is_connected(_bake_navmesh):
		_mesh_spawner.trees_ready.connect(_bake_navmesh)
	_mesh_spawner.spawn_seed = world_seed
	_mesh_spawner.call_deferred("generate_trees")
	
	print("Lancement de la génération d'herbe sur le noeud : ", _grass_gen.name)
	_grass_gen.call_deferred("generate_grass")


# ==========================================
# GESTION DU NAVMESH PROCEDURAL (Terrain3D)
# ==========================================

func _bake_navmesh() -> void:
	var time_nav_start = Time.get_ticks_msec()
	print("NavMesh : nettoyage et préparation de la cuisson en chunks...")
	
	# 1. Nettoyer l'ancien NavMesh monolithique (s'il existe)
	var old_nav = find_child("NavigationRegion3D", true, false)
	if old_nav:
		old_nav.queue_free()
		remove_child(old_nav)
		
	# 2. Nettoyer l'ancien conteneur de chunks
	var old_parent = find_child("NavRegions", true, false)
	if old_parent:
		old_parent.queue_free()
		remove_child(old_parent)
		
	# 3. Créer le nouveau conteneur
	var nav_parent = Node3D.new()
	nav_parent.name = "NavRegions"
	add_child(nav_parent)
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		nav_parent.owner = get_tree().edited_scene_root
		
	# Attendre que le node soit bien ajouté et que Terrain3D se repose
	await get_tree().process_frame
	await get_tree().process_frame

	var total_polygons = 0
	
	var bake_state = {"pending": 0}
	
	for cx in range(map_width_chunks):
		for cy in range(map_height_chunks):
			var nav_region = NavigationRegion3D.new()
			nav_region.name = "NavRegion_%d_%d" % [cx, cy]
			
			var n_mesh = NavigationMesh.new()
			n_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
			n_mesh.cell_size = 0.75
			n_mesh.cell_height = 0.25
			n_mesh.agent_radius = 0.75
			n_mesh.agent_height = 1.8
			n_mesh.agent_max_slope = 40.0
			n_mesh.agent_max_climb = 0.5
			
			nav_region.navigation_mesh = n_mesh
			nav_parent.add_child(nav_region)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				nav_region.owner = get_tree().edited_scene_root
				
			var source_data := NavigationMeshSourceGeometryData3D.new()
			NavigationServer3D.parse_source_geometry_data(n_mesh, source_data, nav_region)
			
			# AABB du chunk (légèrement étendu de 0.8m pour que les bords se connectent sans surcharger Godot)
			var chunk_x := float(cx * region_size)
			var chunk_z := float(cy * region_size)
			var aabb := AABB(Vector3(chunk_x - 0.8, -100.0, chunk_z - 0.8), Vector3(float(region_size) + 1.6, max_height + 200.0, float(region_size) + 1.6))
			
			var faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(aabb)
			if faces.is_empty():
				push_error("MapGenerator: aucune géométrie de terrain pour le NavMesh du chunk (%d, %d)." % [cx, cy])
				nav_region.queue_free()
				continue
			source_data.add_faces(faces, Transform3D.IDENTITY)
			
			bake_state.pending += 1
			
			# Lambda asynchrone passée avec bind pour éviter les soucis de portée de boucle
			var on_bake_done = (func(mesh: NavigationMesh, region: NavigationRegion3D, s: Dictionary):
				region.set_navigation_mesh(null)
				region.set_navigation_mesh(mesh)
				s.pending -= 1
			).bind(n_mesh, nav_region, bake_state)
			
			# Cuisson MULTI-THREAD en parallèle
			NavigationServer3D.bake_from_source_geometry_data_async(n_mesh, source_data, on_bake_done)
			
	# Cuisson du NavMesh pour chaque arène située hors des chunks de la carte principale
	var map_rect: Rect2 = _get_map_rect()
	for zone in get_arena_zones():
		var ax0: float = float(zone["min_x"])
		var ax1: float = float(zone["max_x"])
		var az0: float = float(zone["min_z"])
		var az1: float = float(zone["max_z"])
		var slot: int = int(zone.get("slot", 0))
		
		# Recouvrement de 0.8m sur la bordure de la carte pour connecter le NavMesh de l'arène au chunk voisin
		if slot == ArenaGenerator.SLOT_NORTH:
			az1 = minf(az1, map_rect.position.y + 0.8)
		elif slot == ArenaGenerator.SLOT_WEST:
			ax1 = minf(ax1, map_rect.position.x + 0.8)
		elif slot == ArenaGenerator.SLOT_EAST:
			ax0 = maxf(ax0, map_rect.end.x - 0.8)
			
		if ax1 <= ax0 or az1 <= az0:
			continue
			
		var arena_nav_region := NavigationRegion3D.new()
		arena_nav_region.name = "NavRegion_" + str(zone["name"])
		
		var arena_n_mesh := NavigationMesh.new()
		arena_n_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
		arena_n_mesh.cell_size = 0.75
		arena_n_mesh.cell_height = 0.25
		arena_n_mesh.agent_radius = 0.75
		arena_n_mesh.agent_height = 1.8
		arena_n_mesh.agent_max_slope = 40.0
		arena_n_mesh.agent_max_climb = 0.5
		
		arena_nav_region.navigation_mesh = arena_n_mesh
		nav_parent.add_child(arena_nav_region)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			arena_nav_region.owner = get_tree().edited_scene_root
			
		var arena_source_data := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(arena_n_mesh, arena_source_data, arena_nav_region)
		
		var arena_aabb := AABB(
			Vector3(ax0, -100.0, az0),
			Vector3(ax1 - ax0, max_height + 200.0, az1 - az0)
		)
		var arena_faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(arena_aabb)
		if arena_faces.is_empty():
			push_error("MapGenerator: aucune géométrie de terrain pour le NavMesh de l'arène '%s'." % str(zone["name"]))
			arena_nav_region.queue_free()
			continue
		arena_source_data.add_faces(arena_faces, Transform3D.IDENTITY)
		
		bake_state.pending += 1
		var on_arena_bake_done = (func(mesh: NavigationMesh, region: NavigationRegion3D, s: Dictionary):
			region.set_navigation_mesh(null)
			region.set_navigation_mesh(mesh)
			s.pending -= 1
		).bind(arena_n_mesh, arena_nav_region, bake_state)
		
		NavigationServer3D.bake_from_source_geometry_data_async(arena_n_mesh, arena_source_data, on_arena_bake_done)
			
	# On attend que tous les threads aient terminé
	var wait_start: int = Time.get_ticks_msec()
	while bake_state.pending > 0:
		if Time.get_ticks_msec() - wait_start > NAV_BAKE_TIMEOUT_MS:
			push_error("MapGenerator: timeout de la cuisson NavMesh (%d chunk(s) non terminé(s))." % bake_state.pending)
			break
		await get_tree().create_timer(0.1).timeout
		
	# On compte les polygones après la cuisson de tous les chunks
	total_polygons = 0
	for child in nav_parent.get_children():
		if child is NavigationRegion3D and child.navigation_mesh:
			total_polygons += child.navigation_mesh.get_polygon_count()
	
	var time_nav = Time.get_ticks_msec() - time_nav_start
	print("NavMesh : Cuisson Asynchrone par chunks terminée en ", time_nav, " ms ! Polygones totaux : ", total_polygons)
	
	# Fix Terrain3D : synchroniser avec la caméra active locale
	if not Engine.is_editor_hint():
		var active_cam: Camera3D = get_viewport().get_camera_3d()
		if active_cam == null:
			push_warning("MapGenerator: aucune caméra active, le Terrain3D ne suit aucune caméra.")
		else:
			terrain.set_camera(active_cam)
			print("MapGenerator: Caméra active liée au Terrain3D -> ", active_cam.name)
	
	# L'herbe doit être entièrement générée AVANT terrain_ready (qui déclenche le spawn du joueur)
	if not Engine.is_editor_hint() and _grass_gen.is_generating():
		print("MapGenerator: attente de la fin de génération de l'herbe avant le spawn...")
		await _grass_gen.grass_ready
	
	# Génération d'un occluder de relief pour que les collines masquent les arbres/herbe lointains
	_generate_terrain_occluder()
	
	terrain_ready.emit()
	
	# En éditeur, appel direct de la génération des meutes (en jeu, c'est géré via le signal terrain_ready)
	if Engine.is_editor_hint():
		_monster_packs.generate_monster_packs(world_seed)

## Génère un occluder basse résolution basé sur le relief du terrain
## pour culler automatiquement les arbres, l'herbe et les monstres cachés derrière les collines
func _generate_terrain_occluder() -> void:
	var existing = find_child("TerrainOccluder", true, false)
	if existing != null:
		existing.queue_free()
		
	var map_w: float = float(map_width_chunks * region_size)
	var map_h: float = float(map_height_chunks * region_size)
	var step: float = 32.0
	var nx: int = int(ceil(map_w / step)) + 1
	var nz: int = int(ceil(map_h / step)) + 1
	
	var vertices := PackedVector3Array()
	vertices.resize(nx * nz)
	
	# Abaisser légèrement de 2.5m sous la surface pour éviter de masquer le sol visible
	var height_drop: float = 2.5
	
	# Les échantillons sont limités à (taille - 1) : Terrain3D n'a pas de donnée pile sur le bord extérieur
	for iz in range(nz):
		var pz: float = minf(iz * step, map_h - 1.0)
		for ix in range(nx):
			var px: float = minf(ix * step, map_w - 1.0)
			var h: float = get_terrain_height_at(px, pz)
			if is_nan(h):
				push_error("MapGenerator: hauteur de terrain introuvable en (%.1f, %.1f), occluder non généré." % [px, pz])
				return
			var idx = iz * nx + ix
			vertices[idx] = Vector3(px, h - height_drop, pz)
			
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var i_idx = 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i0 = iz * nx + ix
			var i1 = iz * nx + (ix + 1)
			var i2 = (iz + 1) * nx + ix
			var i3 = (iz + 1) * nx + (ix + 1)
			
			indices[i_idx] = i0
			indices[i_idx + 1] = i2
			indices[i_idx + 2] = i1
			
			indices[i_idx + 3] = i1
			indices[i_idx + 4] = i2
			indices[i_idx + 5] = i3
			i_idx += 6
			
	var occluder = ArrayOccluder3D.new()
	occluder.set_arrays(vertices, indices)
	
	var occluder_inst = OccluderInstance3D.new()
	occluder_inst.name = "TerrainOccluder"
	occluder_inst.occluder = occluder
	add_child(occluder_inst)
	print("MapGenerator: Occluder de terrain généré (", nx * nz, " sommets, ", indices.size() / 3, " triangles).")

## Configure le brouillard de profondeur pour qu'il masque parfaitement la limite de rendu des arbres
func _setup_distance_fog() -> void:
	if not distance_fog_enabled:
		return
	var env_nodes = find_children("*", "WorldEnvironment", true, false)
	for we in env_nodes:
		if we is WorldEnvironment and we.environment != null:
			var env = we.environment
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = distance_fog_begin
			env.fog_depth_end = distance_fog_end
			env.volumetric_fog_length = distance_fog_end
			print("MapGenerator: Brouillard de distance configuré (", distance_fog_begin, "m -> ", distance_fog_end, "m) calé sur les arbres.")
