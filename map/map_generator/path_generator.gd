@tool
extends Node
class_name PathGenerator

@export_category("Paramètres du chemin")
## La largeur de la route
@export var path_width: float = 15.0

var encounter_positions: Array[Vector2] = []
var start_pos: Vector2 = Vector2.ZERO
var exit_west: Vector2 = Vector2.ZERO
var exit_east: Vector2 = Vector2.ZERO
var exit_north: Vector2 = Vector2.ZERO

## Retourne les sorties qui restent ouvertes sur la bordure de la carte (pour découper les ouvertures dans le mur d'arbres).
## Une sortie n'est ouverte que si son slot d'arène (Nord / Ouest / Est) en contient une.
func get_border_exits() -> Array[Vector2]:
	var arena_gen = get_parent().get_arena_generator()
	var result: Array[Vector2] = [start_pos]
	if exit_west != Vector2.ZERO and arena_gen.is_slot_active(arena_gen.SLOT_WEST):
		result.append(exit_west)
	if exit_east != Vector2.ZERO and arena_gen.is_slot_active(arena_gen.SLOT_EAST):
		result.append(exit_east)
	if exit_north != Vector2.ZERO and arena_gen.is_slot_active(arena_gen.SLOT_NORTH):
		result.append(exit_north)
	return result


# Contient tous les segments de notre route (des dictionnaires avec start et end)
var segments: Array[Dictionary] = []

# Générateur de nombres aléatoires déterministe
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var astar_grid: AStarGrid2D = null

var road_grid: Dictionary = {}
var grid_cell_size: float = 64.0

func _ready() -> void:
	add_to_group("PathGenerator")

func generate_branching_path(map_min_x: float, map_max_x: float, map_min_z: float, map_max_z: float, path_seed: int = 0):
	segments.clear()
	rng.seed = path_seed
	print("Génération d'un chemin avec embranchements (Seed: ", path_seed, ")...")
	
	# --- INITIALISATION ASTAR (Évitement des montagnes) ---
	var time_start = Time.get_ticks_msec()
	
	astar_grid = AStarGrid2D.new()
	var cell_res = 4.0 # Résolution Ultra ! (Cases de 4 mètres)
	astar_grid.cell_size = Vector2(cell_res, cell_res)
	var grid_w = int((map_max_x - map_min_x) / cell_res) + 1
	var grid_h = int((map_max_z - map_min_z) / cell_res) + 1
	astar_grid.region = Rect2i(0, 0, grid_w, grid_h)
	# Il est CRUCIAL de ne pas utiliser DIAGONAL_MODE_ALWAYS, sinon l'algorithme
	# peut passer en diagonale entre deux falaises solides et couper à travers la roche !
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_grid.update()
	
	var map_gen = get_parent()
	print("Calcul du relief Ultra-Haute Résolution (", grid_w, "x", grid_h, ") pour AStarGrid2D...")
	for x in range(grid_w):
		for y in range(grid_h):
			var px = map_min_x + x * cell_res
			var pz = map_min_z + y * cell_res
			var h = map_gen.get_base_height_at(px, pz)
			
			var max_slope = 0.0
			# Vérification dans les 8 directions pour être certain de ne pas rater une bosse
			if x > 0: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px - cell_res, pz)) / cell_res)
			if x < grid_w - 1: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px + cell_res, pz)) / cell_res)
			if y > 0: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px, pz - cell_res)) / cell_res)
			if y < grid_h - 1: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px, pz + cell_res)) / cell_res)
			
			var diag_res = cell_res * 1.4142
			if x > 0 and y > 0: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px - cell_res, pz - cell_res)) / diag_res)
			if x < grid_w - 1 and y > 0: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px + cell_res, pz - cell_res)) / diag_res)
			if x > 0 and y < grid_h - 1: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px - cell_res, pz + cell_res)) / diag_res)
			if x < grid_w - 1 and y < grid_h - 1: max_slope = max(max_slope, abs(h - map_gen.get_base_height_at(px + cell_res, pz + cell_res)) / diag_res)
				
			# 40 degrés correspondent à un ratio de pente (tan) d'environ 0.84.
			# Au-delà, c'est un mur infranchissable absolu.
			if max_slope > 0.84:
				astar_grid.set_point_solid(Vector2i(x, y), true)
			else:
				# Système de poids : privilégie massivement le plat, mais autorise les pentes si le détour est trop long.
				# Le poids augmente de façon exponentielle avec la pente.
				var weight = 1.0 + (max_slope * max_slope * 200.0)
				astar_grid.set_point_weight_scale(Vector2i(x, y), weight)
					
	var time_astar = Time.get_ticks_msec() - time_start
	print("=> Grille AStar (" , grid_w * grid_h, " cellules) générée en ", time_astar, " ms.")
	# ------------------------------------------------------
	
	var b_margin: float = map_gen.border_margin
	# Les sorties sur les bordures Nord, Ouest et Est se terminent exactement
	# sur la ligne du mur d'arbres de bordure (b_margin) pour découper l'ouverture
	# et y connecter l'entrée de l'arène.
	var west_offset: float = b_margin
	var east_offset: float = b_margin
	var north_offset: float = b_margin
				
	# Coordonnées du Spawn (Sud, placé un peu en avant du mur pour le confort du joueur)
	var spawn_pos = Vector2((map_min_x + map_max_x) / 2.0, map_max_z - b_margin - 15.0)
	
	# Coordonnées des 3 Sorties (alignées sur le mur d'arbres de bordure)
	exit_west = Vector2(map_min_x + west_offset, rng.randf_range(map_min_z + 200, map_max_z - 200))
	exit_east = Vector2(map_max_x - east_offset, rng.randf_range(map_min_z + 200, map_max_z - 200))
	exit_north = Vector2(rng.randf_range(map_min_x + 200, map_max_x - 200), map_min_z + north_offset)
	
	# Coordonnées des 2 embranchements
	var fork1_y = lerp(map_max_z, map_min_z, rng.randf_range(0.3, 0.45))
	var fork2_y = lerp(map_max_z, map_min_z, rng.randf_range(0.65, 0.8))
	
	var fork1 = Vector2(rng.randf_range(map_min_x + 300, map_max_x - 300), fork1_y)
	var fork2 = Vector2(rng.randf_range(map_min_x + 300, map_max_x - 300), fork2_y)
	
	# Dégagement des obstacles AStar aux ouvertures de bordure pour garantir une route fluide jusqu'au mur
	_clear_exit_obstacle_area(exit_north, 24.0, map_min_x, map_min_z)
	_clear_exit_obstacle_area(exit_west, 24.0, map_min_x, map_min_z)
	_clear_exit_obstacle_area(exit_east, 24.0, map_min_x, map_min_z)
	_clear_exit_obstacle_area(spawn_pos, 24.0, map_min_x, map_min_z)
	
	# --- VALIDATION DES POINTS STRATÉGIQUES ---
	# Seuls le spawn et les embranchements intérieurs sont replacés s'ils tombent sur une falaise
	spawn_pos = _get_closest_valid_point(spawn_pos, map_min_x, map_min_z)
	start_pos = spawn_pos
	fork1 = _get_closest_valid_point(fork1, map_min_x, map_min_z)
	fork2 = _get_closest_valid_point(fork2, map_min_x, map_min_z)
	# -------------------------------------------
	
	# TRONC PRINCIPAL
	create_sub_path(spawn_pos, fork1, map_min_x, map_max_x, map_min_z, map_max_z)
	
	# On décide aléatoirement de quel côté part la première branche
	if rng.randf() > 0.5:
		# Fork 1 s'occupe de la sortie Ouest.
		create_sub_path(fork1, exit_west, map_min_x, map_max_x, map_min_z, map_max_z)
		# Le chemin principal continue vers Fork 2
		create_sub_path(fork1, fork2, map_min_x, map_max_x, map_min_z, map_max_z)
		# Fork 2 s'occupe de la sortie Nord et de la sortie Est
		create_sub_path(fork2, exit_north, map_min_x, map_max_x, map_min_z, map_max_z)
		create_sub_path(fork2, exit_east, map_min_x, map_max_x, map_min_z, map_max_z)
	else:
		# Fork 1 s'occupe de la sortie Est.
		create_sub_path(fork1, exit_east, map_min_x, map_max_x, map_min_z, map_max_z)
		# Le chemin principal continue vers Fork 2
		create_sub_path(fork1, fork2, map_min_x, map_max_x, map_min_z, map_max_z)
		# Fork 2 s'occupe de la sortie Nord et de la sortie Ouest
		create_sub_path(fork2, exit_north, map_min_x, map_max_x, map_min_z, map_max_z)
		create_sub_path(fork2, exit_west, map_min_x, map_max_x, map_min_z, map_max_z)
		
				
	print(segments.size(), " segments de route générés dans tout l'arbre !")
	
	# --- GÉNÉRATION DES ENCOUNTERS (POI) ---
	encounter_positions.clear()
	var main_segments = segments.duplicate()
	
	# Récupération des paramètres depuis le nœud Encounters
	var enc_count: int = 8
	var enc_min_dist: float = 400.0
	var enc_road_dist: float = 150.0
	var encounters_node = get_parent().find_child("Encounters", true, false)
	if encounters_node:
		if "encounter_count" in encounters_node:
			enc_count = encounters_node.encounter_count
		if "min_distance_between_encounters" in encounters_node:
			enc_min_dist = encounters_node.min_distance_between_encounters
		if "min_distance_from_main_roads" in encounters_node:
			enc_road_dist = encounters_node.min_distance_from_main_roads
	
	# --- GÉNÉRATION DES ENCOUNTERS (POI) VIA MITCHELL'S BEST-CANDIDATE ---
	var margin = 250.0 # Marge des bords de la map
	
	for i in range(enc_count):
		var best_candidate: Vector2 = Vector2.ZERO
		var best_score: float = -999999.0
		
		# On génère 100 candidats au hasard et on évalue chacun
		for attempt in range(100):
			var candidate = Vector2(
				rng.randf_range(map_min_x + margin, map_max_x - margin),
				rng.randf_range(map_min_z + margin, map_max_z - margin)
			)
			
			# 1. Distance aux routes
			var dist_road = get_min_distance_to_segments(candidate, main_segments)
			
			# 2. Distance au camp (POI) le plus proche
			var dist_poi = 999999.0
			for existing_pos in encounter_positions:
				var d = candidate.distance_to(existing_pos)
				if d < dist_poi:
					dist_poi = d
					
			# 3. Calcul du score d'éloignement
			var score = 0.0
			var road_valid = (dist_road >= enc_road_dist)
			var poi_valid = (encounter_positions.is_empty() or dist_poi >= enc_min_dist)
			
			if road_valid and poi_valid:
				# Si tout est valide, on cherche à s'éloigner au maximum des autres camps
				score = dist_poi if not encounter_positions.is_empty() else dist_road
			elif road_valid and not poi_valid:
				# Valide pour la route mais trop proche d'un autre camp (malus léger, on maximise dist_poi)
				score = dist_poi - 10000.0
			else:
				# Trop proche de la route (gros malus, priorité à s'éloigner de la route)
				score = dist_road - 50000.0
				
			# On retient le meilleur candidat
			if score > best_score:
				best_score = score
				best_candidate = candidate
				
		# Une fois le meilleur candidat trouvé parmi les 100, on valide qu'il n'est pas dans une montagne
		var valid_candidate = _get_closest_valid_point(best_candidate, map_min_x, map_min_z)
		encounter_positions.append(valid_candidate)
		
	# --- CONNEXION DES ENCOUNTERS ---
	for encounter_pos in encounter_positions:
		var closest_point: Vector2 = _find_closest_point_on_segments(encounter_pos, main_segments)
		# On s'assure que le point d'accroche sur la route est aussi clean, juste au cas où
		closest_point = _get_closest_valid_point(closest_point, map_min_x, map_min_z)
		create_sub_path(closest_point, encounter_pos, map_min_x, map_max_x, map_min_z, map_max_z, path_width * 0.4)
		
	var path_time = Time.get_ticks_msec() - time_start
	print(segments.size(), " segments totaux avec les accès aux Encounters générés en ", path_time, " ms !")
	_build_spatial_grid()

func create_sub_path(point_a: Vector2, point_b: Vector2, map_min_x: float, map_max_x: float, map_min_z: float, map_max_z: float, custom_width: float = -1.0):
	if custom_width < 0.0: custom_width = path_width
	
	var curve = Curve2D.new()
	
	# Utilisation de l'AStarGrid2D s'il a été généré
	if astar_grid == null:
		push_error("PathGenerator: grille AStar absente : generate_branching_path() doit être appelé avant create_sub_path().")
		return
	var c_size = astar_grid.cell_size.x
	var start_cell = Vector2i(
		clamp((point_a.x - map_min_x) / c_size, 0, astar_grid.region.size.x - 1),
		clamp((point_a.y - map_min_z) / c_size, 0, astar_grid.region.size.y - 1)
	)
	var end_cell = Vector2i(
		clamp((point_b.x - map_min_x) / c_size, 0, astar_grid.region.size.x - 1),
		clamp((point_b.y - map_min_z) / c_size, 0, astar_grid.region.size.y - 1)
	)
	
	# On s'assure de ne pas bloquer les points de départ et d'arrivée
	astar_grid.set_point_solid(start_cell, false)
	astar_grid.set_point_solid(end_cell, false)
	
	var grid_path = astar_grid.get_point_path(start_cell, end_cell)
	
	# SI AUCUN CHEMIN N'EST TROUVÉ (plateau isolé, falaise)
	if grid_path.size() == 0:
		var dir_to_a = (point_a - point_b).normalized()
		var test_dist = 20.0
		var max_dist = point_b.distance_to(point_a)
		
		while grid_path.size() == 0 and test_dist < max_dist:
			var test_b = point_b + dir_to_a * test_dist
			var test_end_cell = Vector2i(
				clamp((test_b.x - map_min_x) / c_size, 0, astar_grid.region.size.x - 1),
				clamp((test_b.y - map_min_z) / c_size, 0, astar_grid.region.size.y - 1)
			)
			# On s'assure que la nouvelle case de test n'est pas bloquée
			var prev_solid = astar_grid.is_point_solid(test_end_cell)
			astar_grid.set_point_solid(test_end_cell, false)
			
			grid_path = astar_grid.get_point_path(start_cell, test_end_cell)
			
			if grid_path.size() > 0:
				point_b = test_b
				print("DEBUG PATH : Point inaccessible (plateau). Déplacé de ", test_dist, "m vers la vallée !")
				break
				
			astar_grid.set_point_solid(test_end_cell, prev_solid)
			test_dist += 20.0
	
	if grid_path.size() > 1:
		# print("DEBUG PATH : AStar OK (", grid_path.size(), " pts) de ", point_a, " à ", point_b)
		var waypoints = []
		
		# On ne saute que très peu de points pour respecter le chemin de l'AStar (1 point tous les 16m)
		var step = 2
		for i in range(0, grid_path.size(), step):
			waypoints.append(Vector2(grid_path[i].x + map_min_x, grid_path[i].y + map_min_z))
			
		if waypoints.size() == 0 or waypoints[-1].distance_to(point_b) > (c_size * 2):
			waypoints.append(point_b)
		waypoints[0] = point_a
		
		# Ajout des waypoints à la courbe avec des tangentes douces
		for i in range(waypoints.size()):
			var wp = waypoints[i]
			var dir = Vector2.ZERO
			
			var dist_prev = 0.0
			var dist_next = 0.0
			
			if i > 0: dist_prev = wp.distance_to(waypoints[i-1])
			if i < waypoints.size() - 1: dist_next = wp.distance_to(waypoints[i+1])
			
			if i == 0 and waypoints.size() > 1:
				dir = (waypoints[1] - wp).normalized()
			elif i == waypoints.size() - 1 and waypoints.size() > 1:
				dir = (wp - waypoints[i-1]).normalized()
			elif i > 0 and i < waypoints.size() - 1:
				dir = (waypoints[i+1] - waypoints[i-1]).normalized()
				
			# La tangente NE DOIT PAS dépasser la moitié de la distance entre les points
			# sinon la courbe fait des loopings immenses hors de la zone sûre !
			var tangent_len = min(dist_prev, dist_next) * 0.35
			if i == 0: tangent_len = dist_next * 0.35
			elif i == waypoints.size() - 1: tangent_len = dist_prev * 0.35
			
			curve.add_point(wp, -dir * tangent_len, dir * tangent_len)
	if grid_path.size() <= 1:
		push_error("PathGenerator: l'AStar a ÉCHOUÉ entre %v et %v : la map est scindée en deux, aucune route n'est tracée pour ce tronçon." % [point_a, point_b])
		return
	curve.bake_interval = 50.0
	var baked_points = curve.get_baked_points()
	
	for i in range(baked_points.size() - 1):
		var p1 = baked_points[i]
		var p2 = baked_points[i+1]
		segments.append({
			"start": p1, "end": p2,
			"width": custom_width,
			"min_x": min(p1.x, p2.x), "max_x": max(p1.x, p2.x),
			"min_y": min(p1.y, p2.y), "max_y": max(p1.y, p2.y)
		})

# Fonction mathématique vitale : calcule à quelle distance on est de la route la plus proche !
func get_distance_to_path(point: Vector2) -> float:
	var min_dist = 999999.0
	for seg in segments:
		var dist = distance_to_segment(point, seg["start"], seg["end"])
		if dist < min_dist:
			min_dist = dist
	return min_dist

# Algorithme standard pour trouver la distance entre un point et un segment de ligne
func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2 = a.distance_squared_to(b)
	if l2 == 0.0:
		return p.distance_to(a) # Le segment est un point
	
	# t est le point projeté sur la ligne (clampé entre 0 et 1 pour rester sur le segment)
	var t = max(0, min(1, (p - a).dot(b - a) / l2))
	var projection = a + t * (b - a)
	return p.distance_to(projection)

# Retourne le point le plus proche sur un ensemble de segments
func _find_closest_point_on_segments(p: Vector2, segs: Array) -> Vector2:
	var min_dist = 999999.0
	var closest_point = p
	for seg in segs:
		var a = seg["start"]
		var b = seg["end"]
		var l2 = a.distance_squared_to(b)
		var proj = p
		if l2 != 0.0:
			var t = max(0, min(1, (p - a).dot(b - a) / l2))
			proj = a + t * (b - a)
		var dist = p.distance_to(proj)
		if dist < min_dist:
			min_dist = dist
			closest_point = proj
	return closest_point

## Dégage une zone de cellules dans l'AStar pour garantir qu'une sortie ou arène est accessible
func _clear_exit_obstacle_area(p: Vector2, radius: float, min_x: float, min_z: float) -> void:
	if astar_grid == null:
		return
	var c_size = astar_grid.cell_size.x
	var r_cells = int(ceil(radius / c_size))
	var cx = int(clamp((p.x - min_x) / c_size, 0, astar_grid.region.size.x - 1))
	var cy = int(clamp((p.y - min_z) / c_size, 0, astar_grid.region.size.y - 1))
	for dx in range(-r_cells, r_cells + 1):
		for dy in range(-r_cells, r_cells + 1):
			var test_cell = Vector2i(cx + dx, cy + dy)
			if astar_grid.is_in_boundsv(test_cell):
				astar_grid.set_point_solid(test_cell, false)
				astar_grid.set_point_weight_scale(test_cell, 1.0)

# Helper pour l'AStar : Cherche le point navigable le plus proche (Spirale)
func _get_closest_valid_point(p: Vector2, min_x: float, min_z: float) -> Vector2:
	if astar_grid == null: return p

	
	var c_size = astar_grid.cell_size.x
	var cx = int(clamp((p.x - min_x) / c_size, 0, astar_grid.region.size.x - 1))
	var cy = int(clamp((p.y - min_z) / c_size, 0, astar_grid.region.size.y - 1))
	
	var cell = Vector2i(cx, cy)
	if not astar_grid.is_point_solid(cell):
		return p
		
	# Spirale pour trouver la case navigable la plus proche
	for radius in range(1, 30):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) == radius or abs(dy) == radius:
					var test_cell = cell + Vector2i(dx, dy)
					if astar_grid.is_in_boundsv(test_cell) and not astar_grid.is_point_solid(test_cell):
						var new_p = Vector2(test_cell.x * c_size + min_x, test_cell.y * c_size + min_z)
						print("DEBUG PATH : Point stratégique déplacé d'une montagne ", p, " -> ", new_p)
						return new_p
						
	print("DEBUG PATH : ERREUR FATALE - Impossible de déplacer le point ", p)
	return p # Si tout est bloqué

func get_min_distance_to_segments(point: Vector2, segs: Array) -> float:
	var min_dist = 999999.0
	for seg in segs:
		var dist = distance_to_segment(point, seg["start"], seg["end"])
		if dist < min_dist:
			min_dist = dist
	return min_dist

## Construit une grille spatiale des segments de route pour des requêtes en O(1)
func _build_spatial_grid() -> void:
	road_grid.clear()
	for seg in segments:
		var half_w = seg["width"] * 0.5 + 4.0
		var min_cx = int(floor((seg["min_x"] - half_w) / grid_cell_size))
		var max_cx = int(floor((seg["max_x"] + half_w) / grid_cell_size))
		var min_cy = int(floor((seg["min_y"] - half_w) / grid_cell_size))
		var max_cy = int(floor((seg["max_y"] + half_w) / grid_cell_size))
		
		for cy in range(min_cy, max_cy + 1):
			for cx in range(min_cx, max_cx + 1):
				var key = Vector2i(cx, cy)
				if not road_grid.has(key):
					road_grid[key] = []
				road_grid[key].append(seg)

## Teste ultra-rapidement si un point 2D (x, z) est sur la route
func is_point_on_path(point: Vector2, tolerance: float = 2.0) -> bool:
	if segments.is_empty():
		return false
		
	if not road_grid.is_empty():
		var cell = Vector2i(int(floor(point.x / grid_cell_size)), int(floor(point.y / grid_cell_size)))
		if not road_grid.has(cell):
			return false
		var cell_segments = road_grid[cell]
		for seg in cell_segments:
			var allowed_dist = (seg["width"] * 0.5) + tolerance
			if distance_to_segment(point, seg["start"], seg["end"]) <= allowed_dist:
				return true
		return false
	else:
		# Fallback direct si la grille spatiale n'a pas encore été construite
		for seg in segments:
			var half_w = (seg["width"] * 0.5) + tolerance
			if point.x < seg["min_x"] - half_w or point.x > seg["max_x"] + half_w or point.y < seg["min_y"] - half_w or point.y > seg["max_y"] + half_w:
				continue
			if distance_to_segment(point, seg["start"], seg["end"]) <= half_w:
				return true
		return false
