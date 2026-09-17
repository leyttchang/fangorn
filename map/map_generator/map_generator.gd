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
		call_deferred("generate_terrain_async")
		
func clear_terrain() -> void:
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
		
	print("Terrain nettoyé !")

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
	var ctrl_default: int = ((0 & 0x1F) << 27) | ((1 & 0x1F) << 22)
	var h_smooth_radius: float = 5.0
	if path_generator != null:
		h_smooth_radius = maxf(1.0, path_generator.path_width * 0.3)
	
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
							var ex: float = gx - ax; var ey: float = gz - ay
							dist_sq = ex * ex + ey * ey
						else:
							var t: float = clamp(((gx - ax) * ddx + (gz - ay) * ddy) / l2, 0.0, 1.0)
							var proj_x: float = ax + t * ddx
							var proj_y: float = ay + t * ddy
							var ex: float = gx - proj_x; var ey: float = gz - proj_y
							dist_sq = ex * ex + ey * ey
						
						if dist_sq < seg_w_sq:
							var dist: float = sqrt(dist_sq)
							var t_raw: float = dist / seg_w
							var blend: float = 1.0 - (t_raw * t_raw * (3.0 - 2.0 * t_raw))
							var pidx: int = lz * region_size + lx
							if blend > path_blend_array[pidx]:
								path_blend_array[pidx] = blend
			
			# ===== PHASE 2 : Hauteur Float32 continue + Curve + Control map =====
			# Échantillonne le bruit directement en Float32 (get_noise_2d).
			# ZÉRO quantification 8-bit -> ÉLIMINATION DÉFINITIVE DE L'EFFET ESCALIER !
			var height_bytes: PackedByteArray = PackedByteArray()
			height_bytes.resize(region_size * region_size * 4)
			var ctrl_bytes: PackedByteArray = PackedByteArray()
			ctrl_bytes.resize(region_size * region_size * 4)
			
			var idx: int = 0
			for z in range(region_size):
				if z % 64 == 0 and not Engine.is_editor_hint():
					await get_tree().process_frame
				
				var gz: float = float(chunk_min_z + z)
				
				for x in range(region_size):
					var gx: float = float(chunk_min_x + x)
					
					# Vrai bruit continu 32-bit float [-1.0, 1.0] -> [0.0, 1.0]
					var n: float = noise.get_noise_2d(gx, gz) * 0.5 + 0.5
					
					# Contraste (étire le noir et le blanc, élimine les plaines surélevées)
					var t_contrasted: float = clampf((n - 0.5) * contrast + 0.5, 0.0, 1.0)
					
					# Hauteur continue via la Curve (sample_baked est interne à Godot C++ et ultra fluide)
					var h: float = lerp(min_height, max_height, active_curve.sample_baked(t_contrasted))
					
					var blend: float = path_blend_array[idx]
					if blend > 0.0:
						# Aplatissement du chemin en échantillonnant les 4 voisins
						var nf: float = (
							noise.get_noise_2d(gx + h_smooth_radius, gz) +
							noise.get_noise_2d(gx - h_smooth_radius, gz) +
							noise.get_noise_2d(gx, gz + h_smooth_radius) +
							noise.get_noise_2d(gx, gz - h_smooth_radius)
						) * 0.125 + 0.5
						var tf: float = clampf((nf - 0.5) * contrast + 0.5, 0.0, 1.0)
						var hf: float = lerp(min_height, max_height, active_curve.sample_baked(tf))
						h = lerp(h, hf, blend)
						height_bytes.encode_float(idx * 4, h)
						var blend_byte: int = int(blend * 255.0)
						ctrl_bytes.encode_u32(idx * 4, ((1 & 0x1F) << 22) | ((blend_byte & 0xFF) << 14))
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
	
	print("Génération terminée ! ", chunks_generated, " chunks créés.")
	terrain_ready.emit()
	
	# Génère automatiquement les arbres s'il y a un MeshSpawner
	var mesh_spawner = find_child("MeshSpawner", true, false)
	if mesh_spawner and mesh_spawner.has_method("generate_trees"):
		if "spawn_seed" in mesh_spawner:
			mesh_spawner.spawn_seed = world_seed
		mesh_spawner.call_deferred("generate_trees")
