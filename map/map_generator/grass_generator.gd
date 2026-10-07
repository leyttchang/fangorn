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

@export_category("Placement naturel (patchs / touffes)")
## Force des clairières naturelles (0 = herbe uniforme, 1 = grands patchs nus avec bords doux).
@export_range(0.0, 1.0, 0.05) var patch_strength: float = 0.6
## Taille des patchs (fréquence du bruit : plus petit = patchs plus grands).
@export_range(0.002, 0.1, 0.002) var patch_frequency: float = 0.015
## Hauteur ajoutée aux touffes situées au coeur des patchs (touffes hautes).
@export_range(0.0, 3.0, 0.1) var clod_height_boost: float = 0.8
## Variation de largeur indépendante de la hauteur (0 = brins homothétiques).
@export_range(0.0, 1.0, 0.05) var width_variation: float = 0.25
## Alignement des brins sur la pente du terrain (0 = toujours verticaux, 1 = perpendiculaires au sol).
@export_range(0.0, 1.0, 0.05) var normal_align: float = 0.3
## Inclinaison aléatoire max des brins, en radians (0.12 = ~7°).
@export_range(0.0, 0.5, 0.01) var random_lean: float = 0.12

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
## Vrai quand l'herbe a fini d'être générée (utilisé par le MapGenerator pour attendre avant le spawn joueur)
var grass_done: bool = false
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
	grass_done = false
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

	# Si aucun material_override n'est défini, on récupère le matériau de surface du mesh
	if grass_material == null and grass_mesh != null and grass_mesh.get_surface_count() > 0:
		grass_material = grass_mesh.surface_get_material(0)
		
	# Enregistrement auprès du WindManager pour synchroniser le vent global
	var wind_singleton = get_node_or_null("/root/Wind")
	if wind_singleton != null and grass_material is ShaderMaterial:
		wind_singleton.register_grass_material(grass_material)
		
	rng.seed = 123456 # Même seed que la map pour consistance
	
	# Bruit dédié aux patchs / touffes (déterministe, indépendant de l'export `noise`)
	var patch_noise := FastNoiseLite.new()
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch_noise.seed = 123456
	patch_noise.frequency = patch_frequency
	patch_noise.fractal_octaves = 2
	
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
	
	var b_margin: float = 35.0
	if map_generator != null and "border_margin" in map_generator:
		b_margin = float(map_generator.border_margin)
	elif get_parent() != null and "border_margin" in get_parent():
		b_margin = float(get_parent().border_margin)
		
	var x = b_margin
	var row_count = 0
	
	while x < map_w - b_margin:
		row_count += 1
		# En jeu : génération d'une traite (pendant le chargement, avant le spawn du joueur) = le plus rapide.
		# En éditeur seulement : on rend la main régulièrement pour ne pas figer l'éditeur.
		if Engine.is_editor_hint() and row_count % 16 == 0:
			await get_tree().process_frame
			
		var z = b_margin
		while z < map_h - b_margin:
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
				
			# Patchs naturels : zones plus clairsemées avec bords doux (rejet probabiliste)
			var patch_value: float = (patch_noise.get_noise_2d(px, pz) + 1.0) * 0.5
			var patch_keep: float = lerpf(1.0, smoothstep(0.3, 0.5, patch_value), patch_strength)
			if patch_keep < 1.0 and rng.randf() > patch_keep:
				z += spacing
				continue
			
			var h = terrain.data.get_height(Vector3(px, 0.0, pz))
			if is_nan(h):
				z += spacing
				continue

			# Filtrage des pentes raides (falaises et falaises rocheuses)
			var h_east = terrain.data.get_height(Vector3(px + 1.0, 0.0, pz))
			var h_south = terrain.data.get_height(Vector3(px, 0.0, pz + 1.0))
			if not is_nan(h_east) and not is_nan(h_south):
				if absf(h_east - h) > 0.8 or absf(h_south - h) > 0.8:
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
			
			# --- Placement naturel (inspiré de l'exemple Terrain3D) ---
			# Coeur des patchs = touffes plus hautes ; largeur et hauteur varient indépendamment
			var clod: float = smoothstep(0.55, 0.8, patch_value)
			var scale_w: float = s * (1.0 + rng.randf_range(-width_variation, width_variation))
			var scale_h: float = s * (1.0 + clod * clod_height_boost) * (1.0 + rng.randf_range(-0.15, 0.15))
			
			# Axe "haut" du brin : légèrement aligné sur la pente puis incliné au hasard
			var up_dir: Vector3 = Vector3.UP
			if not is_nan(h_east) and not is_nan(h_south):
				var ground_normal := Vector3(h - h_east, 1.0, h - h_south).normalized()
				up_dir = Vector3.UP.lerp(ground_normal, normal_align).normalized()
			var lean_axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			var lean_angle: float = rng.randf_range(0.0, random_lean)
			if lean_axis.length_squared() > 0.0001:
				up_dir = up_dir.rotated(lean_axis.normalized(), lean_angle).normalized()
			
			# Base orthonormée (X, Y=up_dir, Z) avec rotation aléatoire autour de l'axe du brin
			var rot = rng.randf_range(0.0, PI * 2.0)
			var x_axis := Vector3.RIGHT.rotated(Vector3.UP, rot)
			x_axis = (x_axis - up_dir * x_axis.dot(up_dir)).normalized()
			var z_axis := x_axis.cross(up_dir).normalized()
			
			var basis := Basis(x_axis * scale_w, up_dir * scale_h, z_axis * scale_w)
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
		
		var min_y = INF
		var max_y = -INF
		for i in range(t_arr.size()):
			var tform: Transform3D = t_arr[i]
			mm.set_instance_transform(i, tform)
			if tform.origin.y < min_y: min_y = tform.origin.y
			if tform.origin.y > max_y: max_y = tform.origin.y

		if min_y != INF:
			var min_pos = Vector3(key.x * chunk_size, min_y - 0.5, key.y * chunk_size)
			var max_pos = Vector3((key.x + 1) * chunk_size, max_y + 2.5, (key.y + 1) * chunk_size)
			mm.custom_aabb = AABB(min_pos, max_pos - min_pos)
			
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if grass_material != null:
			mmi.material_override = grass_material
			
		# L'herbe disparaît en douceur par le shader jusqu'à max_draw_distance,
		# le chunk est déchargé par Godot dès qu'il dépasse cette zone.
		mmi.visibility_range_end = max_draw_distance + chunk_size
		mmi.visibility_range_end_margin = 16.0
		
		add_child(mmi)
		
	print("GrassGenerator: Génération terminée ! ", total_grass, " touffes d'herbes plantées dans ", chunks.size(), " chunks. Temps: ", Time.get_ticks_msec() - time_start, " ms.")
	_is_generating = false
	grass_done = true
	grass_ready.emit()
