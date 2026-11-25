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
## Désactive le brouillard et la limite de distance d'affichage des arbres UNIQUEMENT dans l'éditeur Godot (aucun impact en jeu !)
@export var editor_unlimited_view: bool = true:
	set(value):
		editor_unlimited_view = value
		if is_inside_tree():
			_setup_distance_fog()
			_apply_mesh_distance_limits()

const ORACLE_VISION_COCOON_SCENE: PackedScene = preload("res://objet/forest_interactables/oracle_vision/oracle_root_cocoon.tscn")
const LESSER_SKILL_STELE_ENCOUNTER_SCENE: PackedScene = preload("res://map/encounters/lesser_skill_stele/lesser_skill_stele_encounter.tscn")

@export_category("Cocon d'Oracle (Vision Totem Caché)")
## Disperse des grands cocons d'Oracle sauvages au coeur de la forêt (en plus de ceux des camps Orcs)
@export var spawn_oracle_vision_cocoon: bool = true
## Nombre de grands cocons d'Oracle dispersés aléatoirement dans la forêt (par chunk de base, hors chemins)
@export_range(0, 30, 1) var oracle_vision_cocoon_count: int = 6
## Nombre de cocons d'Oracle supplémentaires concentrés aux abords de CHAQUE totem caché (pour guider la fin d'approche)
@export_range(0, 8, 1) var near_hidden_totem_cocoon_count: int = 3

@export_category("Petites Stèles Tier I (Départ & Carte)")
## Garantit 1 Petite Stèle Tier I sur toutes les seeds près du spawn, à une vingtaine de mètres du chemin
@export var spawn_starter_lesser_stele: bool = true
## Nombre maximum de Petites Stèles Tier I supplémentaires placées aléatoirement sur la carte (0 à 3 par défaut)
@export_range(0, 10, 1) var extra_lesser_stele_max_count: int = 3
## Rayon de clairière sans arbres autour de chaque Petite Stèle (évite à 100% tout spawn dans un tronc)
@export var lesser_stele_tree_clear_radius: float = 18.5

## Indique que le terrain, les arbres et le NavMesh sont intégralement prêts
var is_terrain_ready: bool = false
## Positions 2D (X, Z) des Petites Stèles actives (utilisées par MeshSpawner, props et packs sauvages)
var lesser_stele_positions: Array[Vector2] = []
var _spawned_lesser_steles: Array[Node] = []

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

## Segments de route prolongés à l'intérieur des arènes jusqu'aux totems (utilisé par GrassGenerator)
func get_arena_path_segments() -> Array[Dictionary]:
	return get_arena_generator().arena_path_segments


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
	_apply_mesh_distance_limits()
	if not Engine.is_editor_hint():
		# Purger immédiatement les aperçus pré-bakés de l'éditeur avant leurs call_deferred("spawn_mobs")
		var enc_node: Node = get_node_or_null("Encounters")
		if enc_node != null and enc_node.has_method("clear_encounters"):
			enc_node.call("clear_encounters")
		var packs_node: Node = get_node_or_null("MonsterPackGenerator")
		if packs_node != null and packs_node.has_method("clear_monster_packs"):
			packs_node.call("clear_monster_packs")
		_clear_lesser_skill_steles()
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
	_clear_lesser_skill_steles()
	_monster_packs.clear_monster_packs()
	_border_wall.clear_wall()
	_clear_road_forest_props()
	is_terrain_ready = false

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
	if terrain == null or not ("data" in terrain) or terrain.data == null:
		return get_base_height_at(x, z) if (noise != null and height_curve != null) else NAN
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
					if gz < border_margin or gz > float(total_h) - border_margin:
						continue
					var dist_z_border: float = minf(gz - border_margin, float(total_h) - border_margin - gz)
					for lx in range(bx_min, bx_max + 1):
						var gx: float = float(chunk_min_x + lx)
						if gx < border_margin or gx > float(total_w) - border_margin:
							continue
						var dist_to_border: float = minf(dist_z_border, minf(gx - border_margin, float(total_w) - border_margin - gx))
						
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
							var blend: float = (1.0 - (t_val * t_val * (3.0 - 2.0 * t_val))) * clampf(dist_to_border / 4.0, 0.0, 1.0)
							var array_idx: int = lz * region_size + lx
							if blend > path_blend_array[array_idx]:
								path_blend_array[array_idx] = blend
			
			# Prolongement sans surcoût des chemins dans la bande de bordure [0..border_margin] vers l'intérieur des arènes
			for aseg: Dictionary in arena_gen.arena_path_segments:
				var aseg_w: float = float(aseg["width"])
				var aw_pad: float = aseg_w + 4.0
				if float(chunk_max_x) < float(aseg["min_x"]) - aw_pad or float(chunk_min_x) > float(aseg["max_x"]) + aw_pad:
					continue
				if float(chunk_max_z) < float(aseg["min_y"]) - aw_pad or float(chunk_min_z) > float(aseg["max_y"]) + aw_pad:
					continue
				var abx_min: int = maxi(0, int(floor(float(aseg["min_x"]) - aseg_w)) - chunk_min_x - 1)
				var abx_max: int = mini(region_size - 1, int(ceil(float(aseg["max_x"]) + aseg_w)) - chunk_min_x + 1)
				var abz_min: int = maxi(0, int(floor(float(aseg["min_y"]) - aseg_w)) - chunk_min_z - 1)
				var abz_max: int = mini(region_size - 1, int(ceil(float(aseg["max_y"]) + aseg_w)) - chunk_min_z + 1)
				if abx_min > abx_max or abz_min > abz_max:
					continue
				var aa: Vector2 = aseg["start"]
				var ab: Vector2 = aseg["end"]
				var aax: float = aa.x; var aay: float = aa.y
				var addx: float = ab.x - aax; var addy: float = ab.y - aay
				var al2: float = addx * addx + addy * addy
				var aseg_w_sq: float = aseg_w * aseg_w
				for alz in range(abz_min, abz_max + 1):
					var agz: float = float(chunk_min_z + alz)
					var arow: int = alz * region_size
					for alx in range(abx_min, abx_max + 1):
						var agx: float = float(chunk_min_x + alx)
						var adist_sq: float
						if al2 < 0.0001:
							var adx: float = agx - aax; var ady: float = agz - aay
							adist_sq = adx * adx + ady * ady
						else:
							var at_p: float = clampf(((agx - aax) * addx + (agz - aay) * addy) / al2, 0.0, 1.0)
							var adx: float = agx - (aax + at_p * addx)
							var ady: float = agz - (aay + at_p * addy)
							adist_sq = adx * adx + ady * ady
						if adist_sq < aseg_w_sq:
							var at_val: float = sqrt(adist_sq) / aseg_w
							var ablend: float = 1.0 - (at_val * at_val * (3.0 - 2.0 * at_val))
							var a_idx: int = arow + alx
							if ablend > path_blend_array[a_idx]:
								path_blend_array[a_idx] = ablend
			
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
	
	# Placement déterministe des Petites Stèles Tier I (1 garantie près du spawn à ~20m du chemin + jusqu'à 3 aléatoires)
	# Exécuté AVANT MeshSpawner pour garantir 0 arbre dans leur clairière sur 100% des seeds
	_compute_and_spawn_lesser_skill_steles(world_seed)
	
	_apply_mesh_distance_limits()
	
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
	if _mesh_spawner != null and not lesser_stele_positions.is_empty() and _mesh_spawner.has_method("clear_trees_near_positions"):
		_mesh_spawner.clear_trees_near_positions(lesser_stele_positions, lesser_stele_tree_clear_radius)
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
		var dir: Vector2 = zone.get("dir", Vector2.ZERO)
		
		# Recouvrement de 0.8m sur la bordure de la carte pour connecter le NavMesh de l'arène au chunk voisin
		if dir.y < -0.5: # Nord
			az1 = minf(az1, map_rect.position.y + 0.8)
		elif dir.y > 0.5: # Sud
			az0 = maxf(az0, map_rect.end.y - 0.8)
		elif dir.x < -0.5: # Ouest
			ax1 = minf(ax1, map_rect.position.x + 0.8)
		elif dir.x > 0.5: # Est
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
	
	# Génération déterministe des props forestiers (Champignons, Cocons, Racines-Catapultes)
	_spawn_road_forest_props()
	
	is_terrain_ready = true
	terrain_ready.emit()
	
	# En éditeur, appel direct de la génération des meutes (en jeu, c'est géré via le signal terrain_ready)
	if Engine.is_editor_hint():
		_monster_packs.generate_monster_packs(world_seed)

func _clear_lesser_skill_steles() -> void:
	for node_inst: Node in _spawned_lesser_steles:
		if node_inst != null and is_instance_valid(node_inst) and not node_inst.is_queued_for_deletion():
			var sp: MobRaycastSpawner = node_inst.get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner
			if sp != null:
				sp.clear_mobs()
			if node_inst.get_parent() != null:
				node_inst.get_parent().remove_child(node_inst)
			node_inst.queue_free()
	_spawned_lesser_steles.clear()
	lesser_stele_positions.clear()

	var leftover: Array[Node] = []
	for ch: Node in get_children():
		if ch.name.begins_with("LesserSkillSteleEncounter_"):
			leftover.append(ch)
	for lf: Node in leftover:
		remove_child(lf)
		lf.queue_free()


func _check_lesser_stele_ground_and_slope(cand_2d: Vector2, max_slope_deg: float) -> Dictionary:
	var use_base_fallback: bool = (terrain == null or not ("data" in terrain) or terrain.get("data") == null)
	var gy: float = get_base_height_at(cand_2d.x, cand_2d.y) if use_base_fallback else get_terrain_height_at(cand_2d.x, cand_2d.y)
	if is_nan(gy) or is_inf(gy):
		return {"valid": false, "ground_y": NAN, "slope_deg": 90.0}

	var max_slope_rad: float = 0.0
	for probe_d: float in [2.0, 4.2]:
		var he: float = get_base_height_at(cand_2d.x + probe_d, cand_2d.y) if use_base_fallback else get_terrain_height_at(cand_2d.x + probe_d, cand_2d.y)
		var hw: float = get_base_height_at(cand_2d.x - probe_d, cand_2d.y) if use_base_fallback else get_terrain_height_at(cand_2d.x - probe_d, cand_2d.y)
		var hs: float = get_base_height_at(cand_2d.x, cand_2d.y + probe_d) if use_base_fallback else get_terrain_height_at(cand_2d.x, cand_2d.y + probe_d)
		var hn: float = get_base_height_at(cand_2d.x, cand_2d.y - probe_d) if use_base_fallback else get_terrain_height_at(cand_2d.x, cand_2d.y - probe_d)
		if is_nan(he) or is_nan(hw) or is_nan(hs) or is_nan(hn):
			return {"valid": false, "ground_y": NAN, "slope_deg": 90.0}
		var dx: float = (he - hw) / (probe_d * 2.0)
		var dz: float = (hs - hn) / (probe_d * 2.0)
		var sr: float = atan(sqrt(dx * dx + dz * dz))
		if sr > max_slope_rad:
			max_slope_rad = sr

	var slope_deg: float = rad_to_deg(max_slope_rad)
	return {
		"valid": slope_deg <= max_slope_deg,
		"ground_y": gy,
		"slope_deg": slope_deg
	}


func _is_lesser_stele_candidate_clear_of_pois(
	cand_2d: Vector2,
	encounter_pts: Array,
	min_enc_dist: float,
	arena_zones: Array[Dictionary],
	arena_pad: float,
	placed_steles: Array[Vector2],
	min_stele_spacing: float
) -> bool:
	var enc_sq: float = min_enc_dist * min_enc_dist
	for ep in encounter_pts:
		if ep is Vector2 and cand_2d.distance_squared_to(ep as Vector2) < enc_sq:
			return false

	for az: Dictionary in arena_zones:
		if az.has("min_x"):
			if (
				cand_2d.x >= float(az["min_x"]) - arena_pad
				and cand_2d.x <= float(az["max_x"]) + arena_pad
				and cand_2d.y >= float(az["min_z"]) - arena_pad
				and cand_2d.y <= float(az["max_z"]) + arena_pad
			):
				return false

	var sp_sq: float = min_stele_spacing * min_stele_spacing
	for prev: Vector2 in placed_steles:
		if cand_2d.distance_squared_to(prev) < sp_sq:
			return false

	return true


func _find_guaranteed_starter_stele_spot(
	rng: RandomNumberGenerator,
	map_w: float,
	map_h: float,
	encounter_pts: Array,
	arena_zones: Array[Dictionary]
) -> Dictionary:
	var start_2d: Vector2 = path_generator.start_pos
	if start_2d == Vector2.ZERO:
		start_2d = Vector2(map_w * 0.5, map_h - (border_margin + 25.0))

	var near_segments: Array[Dictionary] = []
	for seg: Dictionary in path_generator.segments:
		var a: Vector2 = seg.get("start", Vector2.ZERO)
		var b: Vector2 = seg.get("end", Vector2.ZERO)
		var mid: Vector2 = (a + b) * 0.5
		var d_spawn: float = mid.distance_to(start_2d)
		if d_spawn >= 26.0 and d_spawn <= 170.0 and a.distance_squared_to(b) > 0.25:
			near_segments.append(seg)

	# Passe 1 (Idéale : 38m..95m du spawn, ~17m..25m du bord du chemin -> ~22m..30m du centre, pente <= 26°)
	# Passe 2 (Souple : 32m..145m du spawn, ~14m..29m du bord du chemin, pente <= 35°)
	for pass_idx in range(2):
		var min_spawn_d: float = 38.0 if pass_idx == 0 else 32.0
		var max_spawn_d: float = 95.0 if pass_idx == 0 else 145.0
		var edge_off_min: float = 16.5 if pass_idx == 0 else 14.0
		var edge_off_max: float = 24.5 if pass_idx == 0 else 29.0
		var road_dist_min: float = 18.0 if pass_idx == 0 else 15.0
		var road_dist_max: float = 33.0 if pass_idx == 0 else 39.0
		var max_slope: float = 26.0 if pass_idx == 0 else 35.0
		var wall_pad: float = border_margin + (19.0 if pass_idx == 0 else 15.0)
		var enc_pad: float = 45.0 if pass_idx == 0 else 32.0

		var pass_segs: Array[Dictionary] = []
		for seg: Dictionary in near_segments:
			var mid: Vector2 = ((seg["start"] as Vector2) + (seg["end"] as Vector2)) * 0.5
			var ds: float = mid.distance_to(start_2d)
			if ds >= min_spawn_d - 10.0 and ds <= max_spawn_d + 10.0:
				pass_segs.append(seg)

		if pass_segs.is_empty():
			continue

		for _attempt in range(140):
			var seg: Dictionary = pass_segs[rng.randi_range(0, pass_segs.size() - 1)]
			var a: Vector2 = seg["start"]
			var b: Vector2 = seg["end"]
			var road_pt: Vector2 = a.lerp(b, rng.randf_range(0.1, 0.9))
			var d_to_spawn: float = road_pt.distance_to(start_2d)
			if d_to_spawn < min_spawn_d or d_to_spawn > max_spawn_d:
				continue

			var dir: Vector2 = (b - a).normalized()
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var perp := Vector2(-dir.y, dir.x) * side
			var half_w: float = float(seg.get("width", path_generator.path_width)) * 0.5
			var cand_2d: Vector2 = road_pt + perp * (half_w + rng.randf_range(edge_off_min, edge_off_max))

			if cand_2d.x < wall_pad or cand_2d.x > map_w - wall_pad or cand_2d.y < wall_pad or cand_2d.y > map_h - wall_pad:
				continue

			var cand_spawn_d: float = cand_2d.distance_to(start_2d)
			if cand_spawn_d < min_spawn_d or cand_spawn_d > max_spawn_d + 18.0:
				continue

			var true_road_d: float = path_generator.get_distance_to_path(cand_2d)
			if true_road_d < road_dist_min or true_road_d > road_dist_max:
				continue

			if not _is_lesser_stele_candidate_clear_of_pois(cand_2d, encounter_pts, enc_pad, arena_zones, 20.0, [], 0.0):
				continue

			var g_info: Dictionary = _check_lesser_stele_ground_and_slope(cand_2d, max_slope)
			if not bool(g_info["valid"]):
				continue

			var face_road_yaw: float = atan2(road_pt.x - cand_2d.x, road_pt.y - cand_2d.y) + rng.randf_range(-0.25, 0.25)
			return {
				"pos_2d": cand_2d,
				"ground_y": float(g_info["ground_y"]),
				"rot_y": face_road_yaw,
				"is_starter": true
			}

	# Passe 3 (Garantie mathématique 100% sur toutes les seeds : balayage déterministe choisissant la pente minimale)
	var best_spot: Dictionary = {}
	var best_penalty: float = INF
	var wall_min: float = border_margin + 14.0

	for seg: Dictionary in near_segments:
		var a: Vector2 = seg["start"]
		var b: Vector2 = seg["end"]
		var dir: Vector2 = (b - a).normalized()
		var half_w: float = float(seg.get("width", path_generator.path_width)) * 0.5
		for t_step in [0.25, 0.55, 0.85]:
			var road_pt: Vector2 = a.lerp(b, float(t_step))
			var ds: float = road_pt.distance_to(start_2d)
			if ds < 30.0 or ds > 170.0:
				continue
			for side_s in [-1.0, 1.0]:
				var perp := Vector2(-dir.y, dir.x) * float(side_s)
				for off_d in [16.0, 20.0, 24.0, 29.0]:
					var cand_2d: Vector2 = road_pt + perp * (half_w + float(off_d))
					if cand_2d.x < wall_min or cand_2d.x > map_w - wall_min or cand_2d.y < wall_min or cand_2d.y > map_h - wall_min:
						continue
					if cand_2d.distance_to(start_2d) < 30.0:
						continue
					var rd: float = path_generator.get_distance_to_path(cand_2d)
					if rd < 13.5 or rd > 42.0:
						continue
					if not _is_lesser_stele_candidate_clear_of_pois(cand_2d, encounter_pts, 26.0, arena_zones, 16.0, [], 0.0):
						continue
					var g_info: Dictionary = _check_lesser_stele_ground_and_slope(cand_2d, 89.0)
					if is_nan(float(g_info["ground_y"])):
						continue
					var penalty: float = float(g_info["slope_deg"]) * 3.0 + absf(rd - 23.0) * 1.2 + absf(ds - 60.0) * 0.25
					if penalty < best_penalty:
						best_penalty = penalty
						best_spot = {
							"pos_2d": cand_2d,
							"ground_y": float(g_info["ground_y"]),
							"rot_y": atan2(road_pt.x - cand_2d.x, road_pt.y - cand_2d.y),
							"is_starter": true
						}

	if not best_spot.is_empty():
		return best_spot

	# Secours ultime si aucun segment n'existait
	var fallback_2d := Vector2(
		clampf(start_2d.x + 24.0, wall_min, map_w - wall_min),
		clampf(start_2d.y - 48.0, wall_min, map_h - wall_min)
	)
	var fb_y: float = get_terrain_height_at(fallback_2d.x, fallback_2d.y)
	if is_nan(fb_y):
		fb_y = 0.0
	return {
		"pos_2d": fallback_2d,
		"ground_y": fb_y,
		"rot_y": 0.0,
		"is_starter": true
	}


func _compute_and_spawn_lesser_skill_steles(seed_val: int) -> void:
	_clear_lesser_skill_steles()
	if LESSER_SKILL_STELE_ENCOUNTER_SCENE == null or path_generator == null:
		return
	if not spawn_starter_lesser_stele and extra_lesser_stele_max_count <= 0:
		return

	var map_w: float = float(map_width_chunks * region_size)
	var map_h: float = float(map_height_chunks * region_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, "lesser_skill_steles_v1"])

	var encounter_pts: Array = path_generator.encounter_positions
	var arena_zones: Array[Dictionary] = get_arena_zones()
	var entries: Array[Dictionary] = []

	# 1. Stèle de départ obligatoire sur 100% des seeds (près du spawn, ~20m du chemin)
	if spawn_starter_lesser_stele:
		var starter_entry: Dictionary = _find_guaranteed_starter_stele_spot(rng, map_w, map_h, encounter_pts, arena_zones)
		if not starter_entry.is_empty():
			entries.append(starter_entry)
			lesser_stele_positions.append(starter_entry["pos_2d"] as Vector2)

	# 2. Jusqu'à `extra_lesser_stele_max_count` (3 max par défaut) autres Petites Stèles dispersées sur la map
	if extra_lesser_stele_max_count > 0:
		var min_extra: int = mini(2, extra_lesser_stele_max_count)
		var target_extra: int = rng.randi_range(min_extra, extra_lesser_stele_max_count)
		var safe_margin: float = border_margin + 32.0
		var start_2d: Vector2 = path_generator.start_pos
		var placed_extra: int = 0
		var max_attempts: int = target_extra * 85
		var attempt: int = 0

		while placed_extra < target_extra and attempt < max_attempts and map_w > safe_margin * 2.0 and map_h > safe_margin * 2.0:
			attempt += 1
			var relaxed: bool = attempt > int(max_attempts * 0.62)
			var cand_2d := Vector2(
				rng.randf_range(safe_margin, map_w - safe_margin),
				rng.randf_range(safe_margin, map_h - safe_margin)
			)

			# Rester à bonne distance du spawn (déjà couvert par la stèle garantie)
			if start_2d != Vector2.ZERO and cand_2d.distance_squared_to(start_2d) < (165.0 * 165.0):
				continue

			# Hors de la chaussée (dans les sous-bois / clairières)
			var d_road: float = path_generator.get_distance_to_path(cand_2d)
			if d_road < (18.0 if relaxed else 23.0):
				continue

			var min_spacing: float = 140.0 if relaxed else 210.0
			var min_enc_d: float = 48.0 if relaxed else 62.0
			if not _is_lesser_stele_candidate_clear_of_pois(cand_2d, encounter_pts, min_enc_d, arena_zones, 24.0, lesser_stele_positions, min_spacing):
				continue

			var g_info: Dictionary = _check_lesser_stele_ground_and_slope(cand_2d, 33.0 if relaxed else 27.0)
			if not bool(g_info["valid"]):
				continue

			var closest_road_pt: Vector2 = path_generator._find_closest_point_on_segments(cand_2d, path_generator.segments)
			var yaw: float = rng.randf_range(0.0, TAU)
			if closest_road_pt.distance_squared_to(cand_2d) > 1.0:
				yaw = atan2(closest_road_pt.x - cand_2d.x, closest_road_pt.y - cand_2d.y) + rng.randf_range(-0.45, 0.45)

			entries.append({
				"pos_2d": cand_2d,
				"ground_y": float(g_info["ground_y"]),
				"rot_y": yaw,
				"is_starter": false
			})
			lesser_stele_positions.append(cand_2d)
			placed_extra += 1

	# En multijoueur, les positions sont calculées de façon identique sur serveur & client (pour dégager les mêmes arbres),
	# mais seul le serveur instancie les scènes répliquées dans NetworkObjects.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var net_obj: Node = null
	if not Engine.is_editor_hint() and is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		net_obj = get_tree().current_scene.get_node_or_null("NetworkObjects")

	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var pos_2d: Vector2 = entry["pos_2d"]
		var gy: float = float(entry["ground_y"])
		var rot_y: float = float(entry["rot_y"])
		var is_starter: bool = bool(entry["is_starter"])
		var world_pos := Vector3(pos_2d.x, gy, pos_2d.y)
		var zone_lvl: int = 1 if is_starter else WorldLevelScaler.get_zone_ilvl_at(self, world_pos)

		var inst: Node3D = LESSER_SKILL_STELE_ENCOUNTER_SCENE.instantiate() as Node3D
		if inst == null:
			continue
		inst.name = "LesserSkillSteleEncounter_%d" % (idx + 1)
		inst.set("is_starter_stele", is_starter)
		inst.set("stele_level", zone_lvl)
		inst.position = world_pos
		inst.rotation = Vector3(0.0, rot_y, 0.0)

		if net_obj != null:
			net_obj.add_child(inst, true)
			inst.global_position = world_pos
			inst.global_rotation = Vector3(0.0, rot_y, 0.0)
		else:
			add_child(inst)
			inst.global_position = world_pos
			inst.global_rotation = Vector3(0.0, rot_y, 0.0)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				inst.owner = get_tree().edited_scene_root

		if inst.has_method("snap_camp_to_ground"):
			inst.call("snap_camp_to_ground")
		_spawned_lesser_steles.append(inst)

	print("MapGenerator: %d Petite(s) Stèle(s) Tier I placée(s) (1 départ garantie + %d aléatoire(s))." % [
		entries.size(),
		maxi(0, entries.size() - (1 if spawn_starter_lesser_stele else 0))
	])


func _clear_road_forest_props() -> void:
	var old_oracles: Array[Node] = []
	for child in get_children():
		if child.name.begins_with("OracleVisionCocoon"):
			old_oracles.append(child)
	for o_node in old_oracles:
		remove_child(o_node)
		o_node.queue_free()
	for child in get_children():
		if child.has_method("clear_props"):
			child.clear_props()

func _spawn_road_forest_props() -> void:
	var seed_to_use: int = world_seed
	if not Engine.is_editor_hint() and GameData.current_seed != 0:
		seed_to_use = GameData.current_seed
	for child in get_children():
		if child.has_method("generate_props"):
			child.generate_props(seed_to_use)
	if spawn_oracle_vision_cocoon and (oracle_vision_cocoon_count > 0 or near_hidden_totem_cocoon_count > 0):
		_spawn_oracle_vision_cocoons(seed_to_use)

func _validate_forest_cocoon_spot(
	cand_2d: Vector2,
	margin: float,
	map_w: float,
	map_h: float,
	min_road_clearance: float,
	start_2d: Vector2,
	encounter_pts: Array,
	arena_zones: Array[Dictionary],
	arena_pad: float,
	placed_2d: Array[Vector2],
	min_spacing_sq: float,
	slope_tan_limit: float,
	all_trees: Array
) -> float:
	if cand_2d.x < margin or cand_2d.x > map_w - margin or cand_2d.y < margin or cand_2d.y > map_h - margin:
		return NAN

	if path_generator.is_point_on_path(cand_2d, min_road_clearance):
		return NAN

	if start_2d != Vector2.ZERO and cand_2d.distance_squared_to(start_2d) < 3025.0:
		return NAN

	for ep in encounter_pts:
		if ep is Vector2 and cand_2d.distance_squared_to(ep as Vector2) < 3025.0:
			return NAN

	for ls_pt: Vector2 in lesser_stele_positions:
		if cand_2d.distance_squared_to(ls_pt) < 400.0:
			return NAN

	for az: Dictionary in arena_zones:
		if az.has("min_x"):
			if cand_2d.x >= float(az["min_x"]) - arena_pad and cand_2d.x <= float(az["max_x"]) + arena_pad and cand_2d.y >= float(az["min_z"]) - arena_pad and cand_2d.y <= float(az["max_z"]) + arena_pad:
				return NAN

	for prev_pt: Vector2 in placed_2d:
		if cand_2d.distance_squared_to(prev_pt) < min_spacing_sq:
			return NAN

	var ground_y: float = get_terrain_height_at(cand_2d.x, cand_2d.y)
	if is_nan(ground_y):
		return NAN
	var hx: float = get_terrain_height_at(cand_2d.x + 1.5, cand_2d.y)
	var hz: float = get_terrain_height_at(cand_2d.x, cand_2d.y + 1.5)
	if is_nan(hx) or is_nan(hz):
		return NAN
	if absf(hx - ground_y) / 1.5 > slope_tan_limit or absf(hz - ground_y) / 1.5 > slope_tan_limit:
		return NAN

	for t_chk in all_trees:
		var t_dict: Dictionary = t_chk as Dictionary
		var tp: Vector3 = t_dict.get("trunk_pos", t_dict.get("pos", Vector3.ZERO)) as Vector3
		if absf(tp.x - cand_2d.x) > 5.5 or absf(tp.z - cand_2d.y) > 5.5:
			continue
		var min_r: float = float(t_dict.get("trunk_radius", 1.2)) + 1.45
		var dx_t: float = tp.x - cand_2d.x
		var dz_t: float = tp.z - cand_2d.y
		if dx_t * dx_t + dz_t * dz_t < min_r * min_r:
			return NAN

	return ground_y

func _instantiate_forest_cocoon(cand_2d: Vector2, ground_y: float, rot_y: float, index_num: int) -> bool:
	var cocoon_inst: Node3D = ORACLE_VISION_COCOON_SCENE.instantiate() as Node3D
	if cocoon_inst == null:
		return false
	cocoon_inst.name = "OracleVisionCocoon_" + str(index_num)
	add_child(cocoon_inst)
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		cocoon_inst.owner = get_tree().edited_scene_root
	cocoon_inst.global_transform = Transform3D(Basis(Vector3.UP, rot_y), Vector3(cand_2d.x, ground_y - 0.05, cand_2d.y))
	return true

func _spawn_oracle_vision_cocoons(seed_val: int) -> void:
	if ORACLE_VISION_COCOON_SCENE == null or path_generator == null:
		return

	var t_start_usec: int = Time.get_ticks_usec()
	var map_w: float = float(map_width_chunks * region_size)
	var map_h: float = float(map_height_chunks * region_size)
	var safe_margin: float = border_margin + 38.0
	var near_totem_margin: float = border_margin + 18.0
	if map_w <= safe_margin * 2.0 or map_h <= safe_margin * 2.0:
		return

	var chunk_scale: float = sqrt(maxf(1.0, float(map_width_chunks * map_height_chunks)))
	var wild_target: int = int(round(float(oracle_vision_cocoon_count) * chunk_scale)) if oracle_vision_cocoon_count > 0 else 0

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, "wild_forest_oracle_cocoons"])

	var start_2d: Vector2 = path_generator.start_pos
	var encounter_pts: Array = path_generator.encounter_positions
	var arena_zones: Array[Dictionary] = get_arena_zones()

	var all_trees: Array = []
	if _mesh_spawner != null and "spawned_tree_instances" in _mesh_spawner:
		all_trees = _mesh_spawner.spawned_tree_instances

	var slope_tan_limit: float = tan(deg_to_rad(29.0))
	var placed_2d: Array[Vector2] = []
	var spawned_near_totems: int = 0
	var spawned_wild: int = 0
	var spawned_total: int = 0

	# -------------------------------------------------------------------------
	# PASSE 1 : DENSITÉ ACCRUE EN APPROCHANT DES TOTEMS CACHÉS (~45m .. 190m)
	# -------------------------------------------------------------------------
	if near_hidden_totem_cocoon_count > 0:
		for az: Dictionary in arena_zones:
			if not bool(az.get("has_totem", false)) or not bool(az.get("is_extra", false)):
				continue
			var hole_2d: Vector2 = az.get("pos", Vector2.ZERO) as Vector2
			var out_dir: Vector2 = az.get("dir", Vector2(0.0, -1.0)) as Vector2
			var inward_dir: Vector2 = (-out_dir).normalized()
			if inward_dir.length_squared() < 0.01:
				inward_dir = Vector2(0.0, 1.0)

			var placed_for_this_totem: int = 0
			var near_attempts: int = 0
			while placed_for_this_totem < near_hidden_totem_cocoon_count and near_attempts < 95:
				near_attempts += 1
				var relaxed_near: bool = near_attempts > 60
				# Échelonne les distances (1 proche ~45-85m, 1 intermédiaire ~85-135m, 1 d'approche ~130-190m)
				var band_t: float = float(placed_for_this_totem) / float(maxi(near_hidden_totem_cocoon_count, 1))
				var d_min: float = lerpf(44.0, 128.0, band_t)
				var d_max: float = lerpf(88.0, 192.0, band_t)
				if relaxed_near:
					d_min = 42.0
					d_max = 205.0

				var fan_angle: float = rng.randf_range(-1.18, 1.18)
				var fan_dist: float = rng.randf_range(d_min, d_max)
				var cand_near: Vector2 = hole_2d + inward_dir.rotated(fan_angle) * fan_dist
				var rot_near: float = rng.randf_range(0.0, TAU)
				var near_road_clr: float = 11.0 if relaxed_near else 16.0
				var near_space: float = 34.0 if relaxed_near else 44.0

				var gy_near: float = _validate_forest_cocoon_spot(
					cand_near,
					near_totem_margin,
					map_w,
					map_h,
					near_road_clr,
					start_2d,
					encounter_pts,
					arena_zones,
					18.0,
					placed_2d,
					near_space * near_space,
					slope_tan_limit,
					all_trees
				)
				if is_nan(gy_near):
					continue

				if not _instantiate_forest_cocoon(cand_near, gy_near, rot_near, spawned_total + 1):
					break
				placed_2d.append(cand_near)
				placed_for_this_totem += 1
				spawned_near_totems += 1
				spawned_total += 1

	# -------------------------------------------------------------------------
	# PASSE 2 : DISPERSION SAUVAGE AU CŒUR DE LA FORÊT (HORS CHEMINS)
	# -------------------------------------------------------------------------
	var max_attempts: int = maxi(wild_target * 45, 220)
	var attempt: int = 0

	while spawned_wild < wild_target and attempt < max_attempts:
		attempt += 1
		var relaxed: bool = attempt > int(max_attempts * 0.65)
		var min_road_clearance: float = 13.0 if relaxed else 25.0
		var min_spacing: float = 75.0 if relaxed else 135.0

		var cand_2d := Vector2.ZERO
		var rot_y: float = rng.randf_range(0.0, TAU)

		# ~55% ancrés naturellement près des racines d'un arbre profond de la forêt, ~45% en pleine clairière sauvage
		if not all_trees.is_empty() and rng.randf() < 0.55:
			var t_entry: Dictionary = all_trees[rng.randi_range(0, all_trees.size() - 1)] as Dictionary
			var t_pos: Vector3 = t_entry.get("trunk_pos", t_entry.get("pos", Vector3.ZERO)) as Vector3
			var t_rad: float = float(t_entry.get("trunk_radius", 1.2))
			var ang: float = rng.randf_range(0.0, TAU)
			var dist_r: float = t_rad + rng.randf_range(1.75, 3.60)
			cand_2d = Vector2(t_pos.x + cos(ang) * dist_r, t_pos.z + sin(ang) * dist_r)
			rot_y = atan2(cos(ang), sin(ang)) + rng.randf_range(-0.45, 0.45)
		else:
			cand_2d = Vector2(
				rng.randf_range(safe_margin, map_w - safe_margin),
				rng.randf_range(safe_margin, map_h - safe_margin)
			)

		var ground_y: float = _validate_forest_cocoon_spot(
			cand_2d,
			safe_margin,
			map_w,
			map_h,
			min_road_clearance,
			start_2d,
			encounter_pts,
			arena_zones,
			26.0,
			placed_2d,
			min_spacing * min_spacing,
			slope_tan_limit,
			all_trees
		)
		if is_nan(ground_y):
			continue

		if not _instantiate_forest_cocoon(cand_2d, ground_y, rot_y, spawned_total + 1):
			break
		placed_2d.append(cand_2d)
		spawned_wild += 1
		spawned_total += 1

	var dt_ms: float = float(Time.get_ticks_usec() - t_start_usec) / 1000.0
	print("MapGenerator: %d Grands Cocons d'Oracle générés (%d proches des totems cachés + %d/%d en forêt profonde) en %.2f ms." % [spawned_total, spawned_near_totems, spawned_wild, wild_target, dt_ms])

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
	var hide_fog_in_editor: bool = Engine.is_editor_hint() and editor_unlimited_view
	var env_nodes = find_children("*", "WorldEnvironment", true, false)
	for we in env_nodes:
		if we is WorldEnvironment and we.environment != null:
			if Engine.is_editor_hint() and not we.has_meta("_editor_env_duped"):
				we.environment = we.environment.duplicate()
				we.set_meta("_editor_env_duped", true)
			var env = we.environment
			if hide_fog_in_editor:
				env.fog_enabled = false
				env.volumetric_fog_enabled = false
			elif distance_fog_enabled:
				env.fog_enabled = true
				env.volumetric_fog_enabled = SettingsManager.volumetric_fog_enabled if (not Engine.is_editor_hint() and SettingsManager != null) else true
				env.fog_mode = Environment.FOG_MODE_DEPTH
				env.fog_depth_begin = distance_fog_begin
				env.fog_depth_end = distance_fog_end
				env.volumetric_fog_length = distance_fog_end
				print("MapGenerator: Brouillard de distance configuré (", distance_fog_begin, "m -> ", distance_fog_end, "m) calé sur les arbres.")
			else:
				env.fog_enabled = false
				env.volumetric_fog_enabled = false

## Applique ou retire la limite de distance d'affichage des arbres selon si on est dans l'éditeur ou en jeu
func _apply_mesh_distance_limits() -> void:
	var no_limit: bool = Engine.is_editor_hint() and editor_unlimited_view
	var spawner = get_node_or_null("MeshSpawner")
	if spawner != null:
		for child in spawner.get_children():
			if child is MultiMeshInstance3D:
				child.layers = 2
				child.visibility_range_end = 0.0 if no_limit else 350.0
				child.visibility_range_end_margin = 0.0 if no_limit else 50.0
	var wall = get_node_or_null("BorderTreeWall")
	if wall != null:
		for child in wall.get_children():
			if child is MultiMeshInstance3D:
				child.layers = 2
				child.visibility_range_end = 0.0 if no_limit else 250.0
				child.visibility_range_end_margin = 0.0 if no_limit else 30.0
	var arena_gen = get_arena_generator()
	if arena_gen != null:
		for mmi in arena_gen.find_children("*", "MultiMeshInstance3D", true, false):
			if mmi is MultiMeshInstance3D:
				mmi.layers = 2
				mmi.visibility_range_end = 0.0 if no_limit else 350.0
				mmi.visibility_range_end_margin = 0.0 if no_limit else 50.0
