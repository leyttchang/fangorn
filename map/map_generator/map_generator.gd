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
## Largeur de la carte (en nombre de chunks de 1024m)
@export var map_width_chunks: int = 3
## Longueur de la carte (en nombre de chunks de 1024m)
@export var map_height_chunks: int = 3

@export_category("Élévation & Relief (Méthode 3)")
## Hauteur minimale du terrain (ex: 0.0m pour les plaines de base / niveau de l'eau)
@export var min_height: float = 0.0
## Hauteur maximale atteinte par les plus hauts sommets (ex: 80.0m, 120.0m)
@export var max_height: float = 80.0
## Contraste du relief : étire le bruit pour avoir plus de noir et blanc et moins de gris (élimine la carte surélevée et crée de vraies plaines basses)
@export_range(0.5, 3.5, 0.1) var contrast: float = 1.6
## Courbe de relief : sculpte la forme du monde (plaines plates au début, montées douces, pics au sommet)
@export var height_curve: Curve
## Intensité du lissage (0.0 = aucun, 1.0 = maximum). Lisse les petites déformations sans effacer les collines.
@export_range(0.0, 1.0, 0.05) var smooth_factor: float = 0.3


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
	if not Engine.is_editor_hint():
		# Ne détruire la caméra spectateur que si on est dans le vrai jeu (ex: sous game.tscn)
		if not is_standalone_scene():
			var cam2 = find_child("*Camera*", true, false)
			if cam2 and cam2 is Camera3D:
				cam2.queue_free()
			
		call_deferred("generate_terrain_async")

func is_standalone_scene() -> bool:
	if get_parent() == get_tree().root:
		return true
	if get_tree().current_scene == self or (get_tree().current_scene != null and get_tree().current_scene.name == "Map_generator"):
		return true
	return false
		
func clear_terrain() -> void:
	var time_start = Time.get_ticks_msec()
	print("Nettoyage radical du terrain...")
	var terrain_data = null
	if "data" in terrain: terrain_data = terrain.data
	elif "storage" in terrain: terrain_data = terrain.storage
	
	if terrain_data != null:
		if terrain_data.has_method("get_region_offsets") and terrain_data.has_method("remove_region"):
			var offsets = terrain_data.get_region_offsets()
			for offset in offsets:
				terrain_data.remove_region(offset)
		elif terrain_data.has_method("clear_regions"):
			terrain_data.clear_regions()
			
	if "data_directory" in terrain and terrain.data_directory != "":
		var dir_path = terrain.data_directory
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".res") or file_name.ends_with(".tres") or file_name.ends_with(".dat"):
					dir.remove(file_name)
				file_name = dir.get_next()
			
			terrain.data_directory = ""
			terrain.data_directory = dir_path
			
	var mesh_spawner = find_child("MeshSpawner", true, false)
	if mesh_spawner and mesh_spawner.has_method("clear_trees"):
		mesh_spawner.clear_trees()
		
	var stack = [self]
	while stack.size() > 0:
		var current = stack.pop_back()
		if current != self and current.has_method("clear_grass"):
			current.clear_grass()
		if current != self and current.has_method("clear_encounters"):
			current.clear_encounters()
		stack.append_array(current.get_children())
			
	var time_clean = Time.get_ticks_msec() - time_start
	print("Terrain nettoyé en ", time_clean, " ms !")

func get_spawn_point() -> Vector3:
	if path_generator and path_generator.start_pos != Vector2.ZERO:
		var p2 = path_generator.start_pos
		var ground_y = get_terrain_height_at(p2.x, p2.y)
		print("DEBUG SPAWN: Point calculé = ", p2.x, ", ", ground_y, ", ", p2.y)
		return Vector3(p2.x, ground_y, p2.y)
	
	print("DEBUG SPAWN: Fallback utilisé (0, 100, 0)")
	# Fallback (centre de la map, hauteur arbitraire)
	return Vector3(0, 100, 0)

func _place_encounter_markers(terrain_data) -> void:
	if path_generator == null or not ("encounter_positions" in path_generator):
		return
		
	# On cherche ou on crée le nœud 'Encounters'
	var encounters_node = find_child("Encounters", true, false)
	if encounters_node == null:
		encounters_node = Node3D.new()
		encounters_node.name = "Encounters"
		add_child(encounters_node)
		if Engine.is_editor_hint():
			encounters_node.owner = get_tree().edited_scene_root
			
	# Nettoyer l'existant
	for child in encounters_node.get_children():
		child.queue_free()
		
	var positions = path_generator.encounter_positions
	for i in range(positions.size()):
		var pos2d: Vector2 = positions[i]
		var marker = Marker3D.new()
		marker.name = "encounter_" + str(i + 1)
		
		# Hauteur sur le terrain
		var ground_y = 0.0
		if terrain_data != null and terrain_data.has_method("get_height"):
			ground_y = terrain_data.get_height(Vector3(pos2d.x, 0.0, pos2d.y))
			if is_nan(ground_y): ground_y = 0.0
			
		marker.position = Vector3(pos2d.x, ground_y, pos2d.y)
		
		encounters_node.add_child(marker)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			marker.owner = get_tree().edited_scene_root
			
	print("Markers d'Encounters placés : ", positions.size())
	if encounters_node.has_method("spawn_encounters"):
		encounters_node.call_deferred("spawn_encounters", world_seed)

func _get_active_curve() -> Curve:
	if height_curve != null:
		return height_curve
	# Profil géologique par défaut (plaqué au sol) :
	# - Tout le bas (0% à 50% de bruit) reste collé à 0m (vraies plaines au sol, plus de plateau surélevé)
	# - 50% à 80% : collines douces qui montent
	# - 80% à 100% : hauts sommets et montagnes
	var default_curve = Curve.new()
	default_curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0)
	default_curve.add_point(Vector2(0.5, 0.0), 0.0, 0.2)
	default_curve.add_point(Vector2(0.8, 0.4), 0.8, 1.5)
	default_curve.add_point(Vector2(1.0, 1.0), 2.5, 0.0)
	default_curve.bake()
	return default_curve

func get_terrain_height_at(x: float, z: float) -> float:
	if noise == null: return 0.0
	var n: float = noise.get_noise_2d(x, z) * 0.5 + 0.5
	var t_contrasted: float = clampf((n - 0.5) * contrast + 0.5, 0.0, 1.0)
	return lerp(min_height, max_height, _get_active_curve().sample_baked(t_contrasted))

# Génération asynchrone pour ne JAMAIS faire crasher l'éditeur Godot !
func generate_terrain_async() -> void:
	if terrain == null or noise == null:
		push_error("MapGenerator: Il manque le Terrain3D ou le Noise !")
		return
		
	print("Début de la génération du terrain (Seed: ", world_seed, ")...")
	# Applique la seed sur le bruit de relief du terrain
	noise.seed = world_seed
	clear_terrain()
	
	# Pause d'une frame pour laisser Godot respirer après le nettoyage
	await get_tree().process_frame
	
	var terrain_data = null
	if "data" in terrain: terrain_data = terrain.data
	elif "storage" in terrain: terrain_data = terrain.storage
		
	if terrain_data == null: return
	
	if terrain.assets and terrain.assets.get_texture_count() < 2:
		push_error("MapGenerator: TU N'AS QU'UNE SEULE TEXTURE DANS LE TERRAIN3D ! La route essaie d'utiliser la texture ID 1, mais elle n'existe pas, donc elle apparaît NOIRE. Ajoute une deuxième texture (ex: de la terre) dans l'inspecteur du Terrain3D -> Assets -> Textures.")
		print("ERREUR CRITIQUE : Il manque la texture de route dans Godot.")
	
	# On restreint la taille max pour éviter les crashs (Max 10x10)
	map_width_chunks = clamp(map_width_chunks, 1, 10)
	map_height_chunks = clamp(map_height_chunks, 1, 10)
		
	var map_min_x = 0.0
	var map_max_x = float(map_width_chunks * region_size)
	var map_min_z = 0.0
	var map_max_z = float(map_height_chunks * region_size)
	
	var total_w: int = map_width_chunks * region_size
	var total_h: int = map_height_chunks * region_size
	
	if path_generator != null:
		path_generator.generate_branching_path(map_min_x, map_max_x, map_min_z, map_max_z, world_seed)

		
	var active_curve: Curve = _get_active_curve()
	var chunks_generated: int = 0
	var ctrl_default: int = ((0 & 0x1F) << 27) | ((1 & 0x1F) << 22) | (1 << 1)
	var h_smooth_radius: float = 5.0
	if path_generator != null:
		h_smooth_radius = maxf(1.0, path_generator.path_width * 0.3)
	
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
			if path_generator != null:
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
					
					# Marge plate de 15m aux bords de la map
					var margin: float = 15.0
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
	var meteo_node = find_child("Meteo", true, false)
	if meteo_node == null:
		meteo_node = find_child("meteo", true, false)
		
	if meteo_node and meteo_node.has_method("generate_weather"):
		meteo_node.generate_weather(world_seed)
	
	# Placement des points d'intérêt (Encounters)
	_place_encounter_markers(terrain_data)
	
	
	# Génère automatiquement les arbres s'il y a un MeshSpawner
	var mesh_spawner = find_child("MeshSpawner", true, false)
	if mesh_spawner and mesh_spawner.has_method("generate_trees"):
		if not mesh_spawner.trees_ready.is_connected(_bake_navmesh):
			mesh_spawner.trees_ready.connect(_bake_navmesh)
			
		if "spawn_seed" in mesh_spawner:
			mesh_spawner.spawn_seed = world_seed
		mesh_spawner.call_deferred("generate_trees")
	else:
		# S'il n'y a pas d'arbres à générer, on lance le bake tout de suite
		_bake_navmesh()
		
	var grass_gen = null
	# Recherche récursive de tous les descendants
	var stack = [self]
	while stack.size() > 0:
		var current = stack.pop_back()
		if current != self and current.has_method("generate_grass"):
			grass_gen = current
			break
		stack.append_array(current.get_children())
			
	if grass_gen:
		print("Lancement de la génération d'herbe sur le noeud : ", grass_gen.name)
		grass_gen.call_deferred("generate_grass")
	else:
		print("ATTENTION: Aucun noeud avec le script grass_generator.gd n'a été trouvé dans l'arbre !")

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
			
			var has_faces := false
			if terrain and terrain.has_method("generate_nav_mesh_source_geometry"):
				var faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(aabb)
				if not faces.is_empty():
					source_data.add_faces(faces, Transform3D.IDENTITY)
					has_faces = true
			
			if has_faces:
				bake_state.pending += 1
				
				# Lambda asynchrone passée avec bind pour éviter les soucis de portée de boucle
				var on_bake_done = (func(mesh: NavigationMesh, region: NavigationRegion3D, s: Dictionary):
					region.set_navigation_mesh(null)
					region.set_navigation_mesh(mesh)
					s.pending -= 1
				).bind(n_mesh, nav_region, bake_state)
				
				# Cuisson MULTI-THREAD en parallèle
				NavigationServer3D.bake_from_source_geometry_data_async(n_mesh, source_data, on_bake_done)
				
	# On attend que tous les threads aient terminé
	while bake_state.pending > 0:
		await get_tree().create_timer(0.1).timeout
		
	# On compte les polygones après la cuisson de tous les chunks
	total_polygons = 0
	for child in nav_parent.get_children():
		if child is NavigationRegion3D and child.navigation_mesh:
			total_polygons += child.navigation_mesh.get_polygon_count()
	
	var time_nav = Time.get_ticks_msec() - time_nav_start
	print("NavMesh : Cuisson Asynchrone par chunks terminée en ", time_nav, " ms ! Polygones totaux : ", total_polygons)
	
	# Fix Terrain3D : synchroniser avec la caméra active locale si disponible
	if not Engine.is_editor_hint() and terrain != null:
		var vp = get_viewport()
		if vp != null:
			var active_cam = vp.get_camera_3d()
			if active_cam != null and terrain.has_method("set_camera"):
				terrain.set_camera(active_cam)
				print("MapGenerator: Caméra active liée au Terrain3D -> ", active_cam.name)
	
	terrain_ready.emit()
