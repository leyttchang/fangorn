@tool
extends Node
class_name PathGenerator

@export_category("Paramètres du chemin")
## La largeur de la route
@export var path_width: float = 15.0

var encounter_positions: Array[Vector2] = []

# Contient tous les segments de notre route (des dictionnaires avec start et end)
var segments: Array[Dictionary] = []

# Générateur de nombres aléatoires déterministe
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func generate_branching_path(map_min_x: float, map_max_x: float, map_min_z: float, map_max_z: float, path_seed: int = 0):
	segments.clear()
	rng.seed = path_seed
	print("Génération d'un chemin avec embranchements (Seed: ", path_seed, ")...")
	
	# Coordonnées du Spawn (Milieu de la face Sud)
	var spawn_pos = Vector2((map_min_x + map_max_x) / 2.0, map_max_z)
	
	# Coordonnées des 3 Sorties
	var exit_west = Vector2(map_min_x, rng.randf_range(map_min_z + 200, map_max_z - 200))
	var exit_east = Vector2(map_max_x, rng.randf_range(map_min_z + 200, map_max_z - 200))
	var exit_north = Vector2(rng.randf_range(map_min_x + 200, map_max_x - 200), map_min_z)
	
	# Coordonnées des 2 embranchements
	# Le fork 1 est en bas de la carte, le fork 2 est en haut de la carte
	var fork1_y = lerp(map_max_z, map_min_z, rng.randf_range(0.3, 0.45))
	var fork2_y = lerp(map_max_z, map_min_z, rng.randf_range(0.65, 0.8))
	
	var fork1 = Vector2(rng.randf_range(map_min_x + 300, map_max_x - 300), fork1_y)
	var fork2 = Vector2(rng.randf_range(map_min_x + 300, map_max_x - 300), fork2_y)
	
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
	
	var max_attempts = enc_count * 30
	var attempts = 0
	
	while encounter_positions.size() < enc_count and attempts < max_attempts:
		attempts += 1
		
		# 1. Tirer un point aléatoire
		var margin = 300.0
		var candidate = Vector2(
			rng.randf_range(map_min_x + margin, map_max_x - margin),
			rng.randf_range(map_min_z + margin, map_max_z - margin)
		)
		
		# 2. Distance aux routes
		var dist_to_road = get_min_distance_to_segments(candidate, main_segments)
		if dist_to_road < enc_road_dist:
			continue
			
		# 3. Distance aux autres POI
		var too_close = false
		for existing_pos in encounter_positions:
			if candidate.distance_to(existing_pos) < enc_min_dist:
				too_close = true
				break
		if too_close:
			continue
			
		# 4. Point validé
		encounter_positions.append(candidate)
		
	# --- CONNEXION DES ENCOUNTERS ---
	for encounter_pos in encounter_positions:
		var closest_point: Vector2 = _find_closest_point_on_segments(encounter_pos, main_segments)
		create_sub_path(closest_point, encounter_pos, map_min_x, map_max_x, map_min_z, map_max_z, path_width * 0.4)
		
	print(segments.size(), " segments totaux avec les accès aux Encounters !")

func create_sub_path(point_a: Vector2, point_b: Vector2, map_min_x: float, map_max_x: float, map_min_z: float, map_max_z: float, custom_width: float = -1.0):
	if custom_width < 0.0: custom_width = path_width
	
	var curve = Curve2D.new()
	var main_dir = (point_b - point_a).normalized()
	var perp_dir = main_dir.rotated(PI / 2.0)
	
	var dist_ab = point_a.distance_to(point_b)
	var tangent_len = min(150.0, dist_ab * 0.3)
	
	# Points de courbure qui forcent la route à suivre la direction
	curve.add_point(point_a, -main_dir * tangent_len, main_dir * tangent_len)
	
	var num_waypoints = rng.randi_range(1, 3)
	for i in range(1, num_waypoints + 1):
		var t = float(i) / float(num_waypoints + 1)
		var base_point = point_a.lerp(point_b, t)
		
		var zigzag_strength = rng.randf_range(-dist_ab*0.3, dist_ab*0.3)
		var waypoint = base_point + (perp_dir * zigzag_strength)
		
		waypoint.x = clamp(waypoint.x, map_min_x + 100, map_max_x - 100)
		waypoint.y = clamp(waypoint.y, map_min_z + 100, map_max_z - 100)
		
		var curve_dir = main_dir * rng.randf_range(tangent_len*0.5, tangent_len*1.5)
		curve.add_point(waypoint, -curve_dir, curve_dir)

	curve.add_point(point_b, -main_dir * tangent_len, main_dir * tangent_len)
	
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
		var a: Vector2 = seg["start"]
		var b: Vector2 = seg["end"]
		var l2 = a.distance_squared_to(b)
		var proj: Vector2
		if l2 == 0.0:
			proj = a
		else:
			var t = max(0.0, min(1.0, (p - a).dot(b - a) / l2))
			proj = a + t * (b - a)
			
		var dist = p.distance_to(proj)
		if dist < min_dist:
			min_dist = dist
			closest_point = proj
	return closest_point

func get_min_distance_to_segments(point: Vector2, segs: Array) -> float:
	var min_dist = 999999.0
	for seg in segs:
		var dist = distance_to_segment(point, seg["start"], seg["end"])
		if dist < min_dist:
			min_dist = dist
	return min_dist
