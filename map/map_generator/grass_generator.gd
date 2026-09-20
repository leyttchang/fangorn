@tool
class_name GrassGenerator
extends Node3D

signal grass_ready

@export_category("Références")
@export var map_generator: Node3D
@export var terrain: Terrain3D
@export var path_generator: Node

@export_category("Herbe")
## La scène de ton herbe (un petit bouquet/touffe)
@export var grass_scene: PackedScene

@export_category("Densité & Bruit")
## Plus ce chiffre est petit, plus l'herbe est dense. (Ex: 0.5 = 1 herbe tous les 50cm).
## ATTENTION : en dessous de 0.4, le temps de génération sera plus long !
@export_range(0.3, 2.0, 0.1) var spacing: float = 0.6
## Bruit pour faire des "trous" dans l'herbe (clairières)
@export var noise: FastNoiseLite
## Seuil du bruit (-1.0 à 1.0). Plus c'est bas, plus il y a d'herbe.
@export_range(-1.0, 1.0, 0.05) var noise_threshold: float = 0.0

@export_category("Placement")
@export var jitter: float = 0.25
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
## Distance d'affichage maximum pour l'herbe (HLOD). 80m-120m est parfait pour 144 FPS.
@export var max_draw_distance: float = 100.0

@export_category("Routes")
## Distance (depuis le bord de la route) où l'herbe commence à se clairsemer (mise à l'échelle automatique selon la largeur de chaque chemin)
@export var road_fade_distance: float = 4.0
## Distance (depuis le bord de la route) où il n'y a plus AUCUNE herbe (0%) (mise à l'échelle automatique selon la largeur de chaque chemin)
@export var road_margin: float = 1.0

@export_category("Actions")
@export var generate_now: bool = false:
	set(value):
		generate_now = false
		if Engine.is_editor_hint():
			call_deferred("generate_grass")
			
@export var clear_now: bool = false:
	set(value):
		clear_now = false
		clear_grass()

var _is_generating: bool = false
var rng := RandomNumberGenerator.new()

func clear_grass() -> void:
	for child in get_children():
		if child is MultiMeshInstance3D:
			child.queue_free()
	print("GrassGenerator: Toute l'herbe a été supprimée.")

func generate_grass() -> void:
	if _is_generating:
		print("Déjà en cours de génération...")
		return
		
	if terrain == null or terrain.data == null:
		print("ERREUR GrassGenerator: Le Terrain3D n'a pas été assigné dans l'inspecteur !")
		push_error("GrassGenerator: Terrain3D introuvable ou non initialisé.")
		_is_generating = false
		return
		
	if grass_scene == null:
		print("ERREUR GrassGenerator: Tu as oublié de glisser ta scène d'herbe dans 'Grass Scene' !")
		push_error("GrassGenerator: Aucune PackedScene d'herbe n'a été fournie !")
		_is_generating = false
		return
		
	_is_generating = true
	clear_grass()
	
	print("GrassGenerator: Début de la génération de l'herbe...")
	var time_start = Time.get_ticks_msec()
	
	# Extraction du mesh de la scène d'herbe
	var grass_mesh: Mesh = null
	var grass_material: Material = null
	var instance = grass_scene.instantiate()
	if instance is MeshInstance3D:
		grass_mesh = instance.mesh
		grass_material = instance.material_override
	else:
		var mi = instance.find_children("*", "MeshInstance3D")
		if mi.size() > 0:
			grass_mesh = mi[0].mesh
			grass_material = mi[0].material_override
			
	if grass_mesh == null:
		print("ERREUR GrassGenerator: Ta scène d'herbe ne contient pas de MeshInstance3D !")
		push_error("GrassGenerator: Impossible de trouver un MeshInstance3D dans ta scène d'herbe !")
		_is_generating = false
		return
		
	rng.seed = 123456 # Même seed que la map pour consistance
	
	var map_w: float = 2048.0
	var map_h: float = 2048.0
	if map_generator != null:
		if "map_width_chunks" in map_generator and "region_size" in map_generator:
			map_w = float(map_generator.map_width_chunks * map_generator.region_size)
		if "map_height_chunks" in map_generator and "region_size" in map_generator:
			map_h = float(map_generator.map_height_chunks * map_generator.region_size)
			
	# Récupération de la largeur de base des chemins (pour le calcul du ratio)
	var base_path_width: float = 15.0
	if path_generator != null and "path_width" in path_generator:
		base_path_width = float(path_generator.path_width)
	if base_path_width <= 0.0:
		base_path_width = 15.0
		
	# Grille spatiale ultra rapide pour éviter la route (Road avoidance)
	var road_grid = {}
	if path_generator != null and "segments" in path_generator and path_generator.segments.size() > 0:
		var cell_size = 128.0
		for seg in path_generator.segments:
			var seg_w = float(seg.get("width", base_path_width))
			var ratio = seg_w / base_path_width
			var max_seg_check = maxf(0.0, maxf(road_margin * ratio, road_fade_distance * ratio))
			var check_dist = seg_w + max_seg_check
			var min_cx = int(floor((seg.min_x - check_dist) / cell_size))
			var max_cx = int(floor((seg.max_x + check_dist) / cell_size))
			var min_cz = int(floor((seg.min_y - check_dist) / cell_size))
			var max_cz = int(floor((seg.max_y + check_dist) / cell_size))
			for cz in range(min_cz, max_cz + 1):
				for cx in range(min_cx, max_cx + 1):
					var key = Vector2i(cx, cz)
					if not road_grid.has(key): road_grid[key] = []
					road_grid[key].append(seg)
					
	# Chunking pour le MultiMesh (très important pour les perfs)
	var chunk_size = 64.0
	var chunks = {}
	
	var x = 0.0
	var row_count = 0
	
	while x < map_w:
		row_count += 1
		if row_count % 16 == 0:
			await get_tree().process_frame
			
		var z = 0.0
		while z < map_h:
			var px = x + rng.randf_range(-jitter, jitter)
			var pz = z + rng.randf_range(-jitter, jitter)
			
			# Filtrage Route avec scaling proportionnel à la largeur de chaque chemin
			var min_grass_prob = 1.0
			if not road_grid.is_empty():
				var r_key = Vector2i(int(floor(px / 128.0)), int(floor(pz / 128.0)))
				if road_grid.has(r_key):
					for seg in road_grid[r_key]:
						var ax = seg.start.x; var ay = seg.start.y
						var bx = seg.end.x;   var by = seg.end.y
						var dx = bx - ax;     var dy = by - ay
						var l2 = dx * dx + dy * dy
						var dist_sq = 0.0
						if l2 < 0.0001:
							var ex = px - ax; var ey = pz - ay
							dist_sq = ex * ex + ey * ey
						else:
							var t = clampf(((px - ax) * dx + (pz - ay) * dy) / l2, 0.0, 1.0)
							var ex = px - (ax + t * dx); var ey = pz - (ay + t * dy)
							dist_sq = ex * ex + ey * ey
							
						var seg_w = float(seg.get("width", base_path_width))
						# Ratio de taille du chemin (ex: 1.0 pour la route principale, 0.4 pour les chemins secondaires)
						var ratio = seg_w / base_path_width
						var seg_margin = road_margin * ratio
						var seg_fade = road_fade_distance * ratio
						
						# Distance par rapport au bord de la route
						var actual_dist = sqrt(dist_sq) - seg_w
						
						# Zone 0% d'herbe pour ce chemin
						if actual_dist < seg_margin:
							min_grass_prob = 0.0
							break
						# Zone de transition / fondu progressif
						elif actual_dist < seg_fade:
							var fade_range = maxf(0.01, seg_fade - seg_margin)
							var prob = (actual_dist - seg_margin) / fade_range
							if prob < min_grass_prob:
								min_grass_prob = prob
								
			# Rejet complet si on est dans la zone 0%
			if min_grass_prob <= 0.0:
				z += spacing
				continue
			# Rejet probabiliste (fondu progressif)
			elif min_grass_prob < 1.0:
				if rng.randf() > min_grass_prob:
					z += spacing
					continue
				
			var h = terrain.data.get_height(Vector3(px, 0.0, pz))
			if is_nan(h):
				z += spacing
				continue
				
			# Calcul de l'échelle (Scale) avec le Noise !
			var s = 1.0
			if noise != null:
				# get_noise_2d renvoie entre -1.0 et 1.0. On le ramène entre 0.0 et 1.0
				var n_val = (noise.get_noise_2d(px, pz) + 1.0) * 0.5
				# On interpole entre min_scale et max_scale
				s = lerp(min_scale, max_scale, n_val)
			else:
				# Si pas de noise, taille aléatoire
				s = rng.randf_range(min_scale, max_scale)
				
			# Légère variation aléatoire par-dessus pour ne pas avoir un aspect "trop" parfait
			s += rng.randf_range(-0.1, 0.1) * s
			
			var rot = rng.randf_range(0.0, PI * 2.0)
			
			var basis = Basis(Vector3.UP, rot).scaled(Vector3(s, s, s))
			var tform = Transform3D(basis, Vector3(px, h, pz))
			
			var cx = int(floor(px / chunk_size))
			var cz = int(floor(pz / chunk_size))
			var key = Vector2i(cx, cz)
			
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(tform)
			
			z += spacing
		x += spacing
		
	var total_grass = 0
	for key in chunks.keys():
		var t_arr = chunks[key]
		total_grass += t_arr.size()
		
		var mmi = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = grass_mesh
		mm.instance_count = t_arr.size()
		for i in range(t_arr.size()):
			mm.set_instance_transform(i, t_arr[i])
			
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if grass_material != null:
			mmi.material_override = grass_material
			
		mmi.visibility_range_end = max_draw_distance
		mmi.visibility_range_end_margin = 20.0
		
		add_child(mmi)
		
	print("GrassGenerator: Génération terminée ! ", total_grass, " touffes d'herbes plantées dans ", chunks.size(), " chunks. Temps: ", Time.get_ticks_msec() - time_start, " ms.")
	_is_generating = false
	grass_ready.emit()
