@tool
extends Node3D

@export var terrain: Terrain3D
@export var noise: FastNoiseLite
@export var path_generator: PathGenerator

# Taille d'une région (laisse 1024 pour Terrain3D)
@export var region_size: int = 1024
@export var height_multiplier: float = 50.0

@export_category("Dimensions")
## Largeur de la carte (en nombre de chunks de 1024m)
@export var map_width_chunks: int = 3
## Longueur de la carte (en nombre de chunks de 1024m)
@export var map_height_chunks: int = 3

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
			
	print("Terrain nettoyé !")

# Génération asynchrone pour ne JAMAIS faire crasher l'éditeur Godot !
func generate_terrain_async() -> void:
	if terrain == null or noise == null:
		push_error("MapGenerator: Il manque le Terrain3D ou le Noise !")
		return
		
	print("Début de la génération du terrain...")
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
	
	if path_generator != null:
		path_generator.generate_branching_path(map_min_x, map_max_x, map_min_z, map_max_z)
		
	var chunks_generated = 0
	
	# On génère CHUNK PAR CHUNK avec une pause entre chaque pour ne pas crasher
	for cx in range(map_width_chunks):
		for cz in range(map_height_chunks):
			
			print("Génération mathématique du chunk (", cx, ", ", cz, ")...")
			var time_start = Time.get_ticks_msec()
			
			var chunk_min_x = (cx * region_size)
			var chunk_max_x = (cx * region_size) + region_size
			var chunk_min_z = (cz * region_size)
			var chunk_max_z = (cz * region_size) + region_size
			
			# On pré-filtre les segments qui touchent uniquement CE chunk
			var chunk_segments = []
			var max_path_w = 0.0
			
			if path_generator != null:
				max_path_w = path_generator.path_width + 10.0
				for seg in path_generator.segments:
					var w = seg.width + 10.0
					if not (chunk_max_x < seg.min_x - w or chunk_min_x > seg.max_x + w or chunk_max_z < seg.min_y - w or chunk_min_z > seg.max_y + w):
						chunk_segments.append(seg)
			
			var data = PackedFloat32Array()
			data.resize(region_size * region_size)
			var ctrl_bytes = PackedByteArray()
			ctrl_bytes.resize(region_size * region_size * 4) # FORMAT_RF = 4 octets par pixel
			
			var idx = 0
			var seg_count = chunk_segments.size()
			
			for z in range(region_size):
				var global_z = chunk_min_z + z
				for x in range(region_size):
					var global_x = chunk_min_x + x
					
					var h = noise.get_noise_2d(global_x, global_z) * height_multiplier
					var path_blend = 0.0
					
					if seg_count > 0:
						var best_blend = 0.0
						var best_h_flat = h
						var px = float(global_x)
						var py = float(global_z)
						
						for i in range(seg_count):
							var seg = chunk_segments[i]
							var seg_w = seg.width
							if px < seg.min_x - seg_w - 5.0 or px > seg.max_x + seg_w + 5.0 or py < seg.min_y - seg_w - 5.0 or py > seg.max_y + seg_w + 5.0:
								continue
							var ax = seg.start.x; var ay = seg.start.y
							var bx = seg.end.x; var by = seg.end.y
							var l2 = (ax - bx) * (ax - bx) + (ay - by) * (ay - by)
							var dist = 0.0
							if l2 == 0.0:
								dist = sqrt((px - ax)*(px - ax) + (py - ay)*(py - ay))
							else:
								var t = max(0.0, min(1.0, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
								var proj_x = ax + t * (bx - ax)
								var proj_y = ay + t * (by - ay)
								dist = sqrt((px - proj_x)*(px - proj_x) + (py - proj_y)*(py - proj_y))
							
							if dist < seg_w:
								# Calcule le blend pour CE segment spécifiquement
								var t_raw = clamp(dist / seg_w, 0.0, 1.0)
								var seg_blend = 1.0 - (t_raw * t_raw * (3.0 - 2.0 * t_raw)) # smoothstep
								
								# On garde le MAXIMUM de tous les segments (corrige les encoches aux jonctions)
								if seg_blend > best_blend:
									best_blend = seg_blend
									var sample_r = seg_w * 0.3
									best_h_flat = (
										noise.get_noise_2d(px + sample_r, py) +
										noise.get_noise_2d(px - sample_r, py) +
										noise.get_noise_2d(px, py + sample_r) +
										noise.get_noise_2d(px, py - sample_r)
									) * 0.25 * height_multiplier
						
						path_blend = best_blend
						if path_blend > 0.0:
							h = lerp(h, best_h_flat, path_blend)
					
					data[idx] = h
					
					# --- CONTROL MAP (doc officielle: controlmap_format.html) ---
					# Bits 31-27 : Base texture ID   -> (id & 0x1F) << 27
					# Bits 26-22 : Overlay texture ID -> (id & 0x1F) << 22
					# Bits 21-14 : Blend 0-255        -> (blend & 0xFF) << 14
					# Bit 0      : Autoshader=0 obligatoire pour que notre peinture soit respectée
					#
					# BLENDING : Base=Herbe(0), Overlay=Terre(1), Blend=path_blend*255
					# → 0 = 100% herbe, 255 = 100% terre, intermédiaire = fondu progressif
					var base_id:    int = 0  # Herbe partout en base
					var overlay_id: int = 1  # Terre en overlay (appliquée selon Blend)
					var blend_byte: int = int(clamp(path_blend * 255.0, 0.0, 255.0))
					var ctrl: int = ((base_id & 0x1F) << 27) | ((overlay_id & 0x1F) << 22) | ((blend_byte & 0xFF) << 14)
					ctrl_bytes.encode_u32(idx * 4, ctrl)
					
					idx += 1
			
			var time_end = Time.get_ticks_msec()
			print("Chunk ", cx, ",", cz, " calculé en ", (time_end - time_start), " ms (Segments: ", seg_count, ")")
					
			var img = Image.create_from_data(region_size, region_size, false, Image.FORMAT_RF, data.to_byte_array())
			# Le control map doit aussi être FORMAT_RF (uint32 déguisé en float, comme dans la doc)
			var control_img = Image.create_from_data(region_size, region_size, false, Image.FORMAT_RF, ctrl_bytes)
			var chunk_pos = Vector3(chunk_min_x, 0, chunk_min_z)
			
			terrain_data.import_images([img, control_img, null], chunk_pos, 0.0, 1.0)
			chunks_generated += 1
			
			# Laisse Godot respirer (affiche l'image à l'écran, rafraîchit la barre de progression)
			await get_tree().process_frame
	
	print("Génération complètement terminée ! ", chunks_generated, " chunks créés.")
