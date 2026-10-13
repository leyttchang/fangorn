@tool
class_name ArenaGenerator
extends Node3D

## Composant enfant du MapGenerator qui gère les arènes de boss aux sorties de la carte.
## Chaque slot (Nord / Ouest / Est) contient une liste de scènes d'arène : au début de la génération,
## UNE scène est tirée au hasard par slot (déterministe d'après la seed du monde) et instanciée
## à la sortie correspondante. Un slot vide = pas d'arène : la sortie reste fermée par le mur d'arbres.

const SLOT_NORTH: int = 0
const SLOT_WEST: int = 1
const SLOT_EAST: int = 2
const SLOT_NAMES: Array[String] = ["Arena_North", "Arena_West", "Arena_East"]

@export_category("Slots d'arènes")
## Arènes possibles à la sortie NORD (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var north_arenas: Array[PackedScene] = []
## Arènes possibles à la sortie OUEST (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var west_arenas: Array[PackedScene] = []
## Arènes possibles à la sortie EST (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var east_arenas: Array[PackedScene] = []

@export_category("Sol d'arène")
## Distance (depuis le bord de la map) sur laquelle le sol passe du relief réel du bord à l'altitude de l'entrée
## de l'arène, puis reste parfaitement plat. Plus c'est grand, plus les pentes sur les côtés sont douces.
@export var arena_ground_blend_distance: float = 90.0
## Taille des cellules du sol d'arène (maillage de secours). Doit diviser region_size pour s'aligner pile sur le bord de la map.
@export var arena_ground_cell_size: float = 4.0
## Profondeur de la jupe qui ferme le pourtour du sol de secours sous l'arène.
@export var arena_ground_skirt_depth: float = 12.0

var _arena_flat_zones: Array[Dictionary] = []
## Régions Terrain3D (indices) ajoutées hors de la map pour prolonger le sol sous les arènes
var _outside_regions: Dictionary = {}
## Contours (coordonnées monde XZ) de l'intérieur des arènes : GrassGenerator y plante aussi de l'herbe
var arena_grass_polygons: Array[PackedVector2Array] = []
## Scène choisie pour chaque slot (clé = SLOT_*), remplie par select_arenas()
var _selected_scenes: Dictionary = {}
var _selection_done: bool = false

# --- Accès aux réglages du MapGenerator parent ---
var map_generator: Node3D:
	get: return get_parent() as Node3D
var terrain: Terrain3D:
	get: return map_generator.get("terrain") if map_generator != null else null
var noise: FastNoiseLite:
	get: return map_generator.get("noise") if map_generator != null else null
var path_generator: Node:
	get: return map_generator.get("path_generator") if map_generator != null else null
var region_size: int:
	get: return int(map_generator.get("region_size")) if map_generator != null else 1024
var map_width_chunks: int:
	get: return int(map_generator.get("map_width_chunks")) if map_generator != null else 3
var map_height_chunks: int:
	get: return int(map_generator.get("map_height_chunks")) if map_generator != null else 3
var border_margin: float:
	get: return float(map_generator.get("border_margin")) if map_generator != null else 35.0
var world_seed: int:
	get: return int(map_generator.get("world_seed")) if map_generator != null else 0
var min_height: float:
	get: return float(map_generator.get("min_height")) if map_generator != null else 0.0
var max_height: float:
	get: return float(map_generator.get("max_height")) if map_generator != null else 80.0
var contrast: float:
	get: return float(map_generator.get("contrast")) if map_generator != null else 1.6


func _get_active_curve() -> Curve:
	return map_generator._get_active_curve()


func _get_map_rect() -> Rect2:
	return map_generator._get_map_rect()


func _sample_edge_height(x: float, z: float) -> float:
	return map_generator._sample_edge_height(x, z)


# --- Sélection des arènes ---

## Tire au hasard UNE arène par slot (déterministe d'après la seed). À appeler au début de la génération,
## avant la génération des routes (les sorties dépendent des slots actifs).
func select_arenas(seed_value: int) -> void:
	_selected_scenes.clear()
	var slots: Array = [north_arenas, west_arenas, east_arenas]
	for loc in range(slots.size()):
		var candidates: Array[PackedScene] = []
		for scn in slots[loc]:
			if scn != null:
				candidates.append(scn)
		if candidates.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, loc, "arena_slot"])
		_selected_scenes[loc] = candidates[rng.randi_range(0, candidates.size() - 1)]
		print("ArenaGenerator: slot %s => %s" % [SLOT_NAMES[loc], _selected_scenes[loc].resource_path])
	_selection_done = true


func _ensure_selection() -> void:
	if not _selection_done:
		select_arenas(world_seed)


## Vrai si le slot (SLOT_NORTH / WEST / EAST) a une arène sélectionnée
func is_slot_active(location: int) -> bool:
	_ensure_selection()
	return _selected_scenes.has(location)


func get_zones() -> Array[Dictionary]:
	return _arena_flat_zones


## Liste standardisée des arènes sélectionnées (une par slot actif)
func _get_active_arenas() -> Array[Dictionary]:
	_ensure_selection()
	var result: Array[Dictionary] = []
	for loc in [SLOT_NORTH, SLOT_WEST, SLOT_EAST]:
		if not _selected_scenes.has(loc):
			continue
		result.append({
			"name": SLOT_NAMES[loc],
			"scene": _selected_scenes[loc],
			"location": loc,
			"custom_position": Vector2.ZERO,
			"flat_radius": 35.0,
			"blend_radius": 15.0,
			"border_offset": border_margin,
			"close_border": true
		})
	return result


## Supprime les arènes générées, leurs sols de secours, et les régions Terrain3D ajoutées hors de la map
func clear_arenas() -> void:
	var to_remove: Array[Node] = []
	for child in get_children():
		if child is Node3D and (child.is_in_group("BossArena") or child.name.begins_with("Arena_")):
			to_remove.append(child)
	for a in to_remove:
		remove_child(a)
		a.queue_free()
	_arena_flat_zones.clear()
	arena_grass_polygons.clear()
	
	var terrain_data = null
	if terrain != null and "data" in terrain:
		terrain_data = terrain.data
	if terrain_data != null and terrain_data.has_method("get_region_locations") and terrain_data.has_method("remove_regionl"):
		var map_rect: Rect2 = _get_map_rect()
		for loc in terrain_data.get_region_locations():
			var r_rect := Rect2(float(loc.x * region_size), float(loc.y * region_size), float(region_size), float(region_size))
			if not map_rect.encloses(r_rect):
				terrain_data.remove_regionl(loc)
	_outside_regions.clear()


func _resolve_arena_position(arena_data: Dictionary) -> Vector2:
	var loc = arena_data.get("location", 0)
	if loc == 3: # CUSTOM
		return arena_data.get("custom_position", Vector2.ZERO)
	var b_margin: float = border_margin
	var map_w: float = float(map_width_chunks * region_size)
	var map_h: float = float(map_height_chunks * region_size)
	match loc:
		0: # NORTH : trou dans le mur Nord à Z = b_margin
			var ex_x: float = map_w * 0.5
			if path_generator != null and path_generator.exit_north != Vector2.ZERO:
				ex_x = path_generator.exit_north.x
			return Vector2(ex_x, b_margin)
		1: # WEST : trou dans le mur Ouest à X = b_margin
			var ex_y: float = map_h * 0.5
			if path_generator != null and path_generator.exit_west != Vector2.ZERO:
				ex_y = path_generator.exit_west.y
			return Vector2(b_margin, ex_y)
		2: # EAST : trou dans le mur Est à X = map_w - b_margin
			var ex_y: float = map_h * 0.5
			if path_generator != null and path_generator.exit_east != Vector2.ZERO:
				ex_y = path_generator.exit_east.y
			return Vector2(map_w - b_margin, ex_y)
	return Vector2.ZERO

func _resolve_arena_direction(arena_data: Dictionary, pos: Vector2) -> Vector2:
	var loc = arena_data.get("location", 0)
	match loc:
		0: return Vector2(0, -1) # NORTH : vers le Nord (extérieur)
		1: return Vector2(-1, 0) # WEST  : vers l'Ouest (extérieur)
		2: return Vector2(1, 0)  # EAST  : vers l'Est (extérieur)
	if loc == 3: # CUSTOM
		var map_w: float = float(map_width_chunks * region_size)
		var map_h: float = float(map_height_chunks * region_size)
		var map_c = Vector2(map_w * 0.5, map_h * 0.5)
		return (pos - map_c).normalized()
	return Vector2(0, -1)

## Analyse géométrique dynamique de la courbe ou des marqueurs d'une scène d'arène
## Calcule le centre réel et l'emprise maximale par rapport au Marker3D 'entry'
func _get_arena_curve_geometry(arena_scene: PackedScene) -> Dictionary:
	var default_res = {
		"has_curve": false,
		"local_center": Vector2(0.0, -95.0),
		"radius": 140.0,
		"flat_radius": 185.0,
		"blend_radius": 45.0
	}
	if arena_scene == null:
		return default_res
		
	var inst = arena_scene.instantiate()
	if inst == null:
		return default_res
		
	var entry_node = inst.find_child("entry", true, false)
	var entry_pos: Vector3 = entry_node.position if entry_node != null else Vector3.ZERO
	
	var points_local: Array[Vector2] = []
	
	# 1. Recherche dans les Path3D (ex: courbe d'arène dessinée dans MarkerTreeSpawnerComponent)
	for child in inst.find_children("*", "Path3D", true, false):
		if child is Path3D and child.curve != null:
			var curr: Node = child
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			var baked = child.curve.get_baked_points()
			for pt in baked:
				var p_scene = rel_t * pt - entry_pos
				points_local.append(Vector2(p_scene.x, p_scene.z))
				
	# 2. Recherche dans les Line2D
	if points_local.is_empty():
		for child in inst.find_children("*", "Line2D", true, false):
			if child is Line2D and not child.points.is_empty():
				for pt in child.points:
					var p_scene = Vector3(child.position.x + pt.x, 0.0, child.position.y + pt.y) - entry_pos
					points_local.append(Vector2(p_scene.x, p_scene.z))
					
	# 3. Recherche dans les Marker3D
	if points_local.is_empty():
		for child in inst.find_children("*", "Marker3D", true, false):
			if child != entry_node and child is Marker3D:
				var curr: Node = child
				var rel_t: Transform3D = Transform3D.IDENTITY
				while curr != null and curr != inst:
					if curr is Node3D:
						rel_t = curr.transform * rel_t
					curr = curr.get_parent()
				var p_scene = rel_t.origin - entry_pos
				points_local.append(Vector2(p_scene.x, p_scene.z))
				
	inst.queue_free()
	
	if points_local.is_empty():
		return default_res
		
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	
	for pt in points_local:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
		min_z = minf(min_z, pt.y)
		max_z = maxf(max_z, pt.y)
		
	var local_center = Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	var max_dist: float = 0.0
	for pt in points_local:
		var d = pt.distance_to(local_center)
		if d > max_dist:
			max_dist = d
			
	var half_diag = Vector2((max_x - min_x) * 0.5, (max_z - min_z) * 0.5).length()
	var base_radius = maxf(max_dist, half_diag)
	
	# Marge de sécurité généreuse (+40m) pour garantir que toute l'arène et son pourtour soient entièrement sur du sol plat
	var safety_margin: float = 40.0
	var flat_radius = base_radius + safety_margin
	var blend_radius = 45.0
	
	return {
		"has_curve": true,
		"local_center": local_center,
		"radius": base_radius,
		"flat_radius": flat_radius,
		"blend_radius": blend_radius,
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z
	}

## Initialise les zones de sol plat pour toutes les arènes actives
func init_zones() -> void:
	_arena_flat_zones.clear()
	var active_curve = _get_active_curve()
	var active = _get_active_arenas()
	
	for a in active:
		var hole_pos = _resolve_arena_position(a)
		if hole_pos == Vector2.ZERO:
			continue
		var dir = _resolve_arena_direction(a, hole_pos)
		
		# Analyse géométrique dynamique de la courbe de l'arène
		var geom = _get_arena_curve_geometry(a.get("scene", null))
		
		# Calcul de l'orientation 3D pour projeter le centre local de la courbe dans le monde
		var forward_3d = Vector3(dir.x, 0.0, dir.y).normalized()
		var arena_basis = Basis.looking_at(forward_3d, Vector3.UP) if forward_3d.length_squared() > 0.001 else Basis()
		var local_c = geom["local_center"]
		var offset_3d = arena_basis * Vector3(local_c.x, 0.0, local_c.y)
		var center = hole_pos + Vector2(offset_3d.x, offset_3d.z)
		
		# Hauteur du sol plat échantillonnée à l'entrée (trou) pour un raccordement sans marche
		var n_hole: float = noise.get_noise_2d(hole_pos.x, hole_pos.y) * 0.5 + 0.5
		var t_hole: float = clampf((n_hole - 0.5) * contrast + 0.5, 0.0, 1.0)
		var flat_h: float = lerp(min_height, max_height, active_curve.sample_baked(t_hole))
		
		# Rayon dynamique généreux : s'adapte à la courbe (ou utilise la valeur manuelle si plus grande)
		var flat_r: float = geom["flat_radius"]
		if not geom["has_curve"] and a.get("flat_radius", 0.0) > 0.0:
			flat_r = a["flat_radius"]
		elif a.get("flat_radius", 0.0) > flat_r:
			flat_r = a["flat_radius"]
			
		var blend_r: float = geom["blend_radius"]
		if not geom["has_curve"] and a.get("blend_radius", 0.0) > 0.0:
			blend_r = a["blend_radius"]
		elif a.get("blend_radius", 0.0) > blend_r:
			blend_r = a["blend_radius"]
			
		var total_r: float = flat_r + blend_r
		
		var zone = {
			"name": a["name"],
			"scene": a["scene"],
			"pos": hole_pos,
			"dir": dir,
			"center": center,
			"height": flat_h,
			"flat_radius": flat_r,
			"blend_radius": blend_r,
			"total_radius": total_r,
			"min_x": center.x - total_r,
			"max_x": center.x + total_r,
			"min_z": center.y - total_r,
			"max_z": center.y + total_r
		}
		_arena_flat_zones.append(zone)
		
		print("Arène '%s': Sol plat adapté à la courbe au centre %v (h=%.2fm, rayon_plat=%.1fm, blend=%.1fm, courbe=%s, Trou=%v)." % [
			zone.name, zone.center, zone.height, zone.flat_radius, zone.blend_radius, str(geom["has_curve"]), zone.pos
		])

## Instancie et configure toutes les arènes sur la carte
func spawn_arenas() -> void:
	if _arena_flat_zones.is_empty():
		init_zones()
		
	if _arena_flat_zones.is_empty():
		print("MapGenerator: Aucune arène configurée à générer.")
		return
		
	# Nettoyer les anciennes arènes
	var old_arenas: Array[Node] = []
	for child in get_children():
		if child is Node3D and (child.is_in_group("BossArena") or child.name.begins_with("Arena_")):
			old_arenas.append(child)
	for a in old_arenas:
		a.queue_free()
		remove_child(a)
	arena_grass_polygons.clear()
		
	var mesh_spawner = map_generator.find_child("MeshSpawner", true, false)
	
	# Altitude de chaque entrée d'arène (relief réel du bord de la map), connue avant de remplir les sols
	for z in _arena_flat_zones:
		z["height"] = _sample_edge_height(z.pos.x, z.pos.y)
	
	for zone in _arena_flat_zones:
		var scn: PackedScene = zone["scene"]
		if scn == null:
			continue
			
		var arena_inst = scn.instantiate() as Node3D
		if arena_inst == null:
			continue
			
		arena_inst.name = zone["name"]
		arena_inst.add_to_group("BossArena")
		
		# 1. Orientation vers l'extérieur (hors de la carte)
		var forward_3d = Vector3(zone.dir.x, 0.0, zone.dir.y).normalized()
		if forward_3d.length_squared() > 0.001:
			arena_inst.transform.basis = Basis.looking_at(forward_3d, Vector3.UP)
			
		# 2. Positionnement : aligner le Marker3D 'entry' exactement sur le milieu du trou dans les arbres
		var ground_y: float = _sample_edge_height(zone.pos.x, zone.pos.y)
		zone["height"] = ground_y
		var hole_pos_3d: Vector3 = Vector3(zone.pos.x, ground_y, zone.pos.y)
		
		var entry_marker = arena_inst.find_child("entry", true, false)
		var local_entry_pos: Vector3 = entry_marker.position if entry_marker != null else Vector3.ZERO
		arena_inst.position = hole_pos_3d - arena_inst.basis * local_entry_pos
		
		# Désactiver l'auto-spawn immédiat des arbres pour qu'ils soient générés proprement une fois l'arène placée
		var tree_spawners: Array[Node] = []
		for child in arena_inst.find_children("*", "", true, false):
			if child is MarkerTreeSpawnerComponent:
				child.auto_spawn_on_ready = false
				tree_spawners.append(child)
				
		add_child(arena_inst)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			arena_inst.owner = get_tree().edited_scene_root
			
		arena_inst.force_update_transform()
		
		# 3. Sol sous l'arène (sans modifier la scène originale) : prolongement du vrai Terrain3D
		# (même shader => aucune ligne de raccord). Maillage de secours si Terrain3D refuse.
		var footprint: PackedVector2Array = _get_arena_footprint(arena_inst, zone)
		var inner_poly: PackedVector2Array = _get_arena_footprint(arena_inst, zone, false)
		if inner_poly.size() >= 3:
			arena_grass_polygons.append(inner_poly)
		if not _extend_terrain_under_arena(footprint):
			_create_arena_ground(arena_inst, zone)
		
		# Ordonner explicitement à chaque MarkerTreeSpawnerComponent de générer les arbres maintenant que le terrain plat est prêt
		var border_wall = map_generator.find_child("BorderTreeWall", true, false)
		for spawner in tree_spawners:
			spawner.terrain = terrain
			spawner.height_provider = Callable(map_generator, "get_terrain_height_at")
			# Synchroniser l'échelle des arbres de l'arène avec les arbres géants du mur de frontière
			if border_wall != null and "min_scale" in border_wall and "max_scale" in border_wall:
				spawner.min_scale = border_wall.min_scale
				spawner.max_scale = border_wall.max_scale
			spawner.spawn_trees()
			
		# Nettoyer les arbres de forêt MeshSpawner à proximité du centre de l'arène
		if mesh_spawner and mesh_spawner.has_method("clear_trees_in_radius"):
			var arena_center_3d = Vector3(zone.center.x, ground_y, zone.center.y)
			mesh_spawner.clear_trees_in_radius(arena_center_3d, zone.flat_radius + 5.0)
			
		var actual_entry = arena_inst.find_child("entry", true, false)
		var actual_entry_pos = actual_entry.global_position if actual_entry != null else arena_inst.global_position
		print("MapGenerator: Arène '%s' générée (Orientation: %v) avec 'entry' aligné à %v (Trou: %v)." % [
			arena_inst.name, arena_inst.rotation_degrees, actual_entry_pos, hole_pos_3d
		])


## Altitude de l'entrée de l'arène la plus proche d'un point (NAN s'il n'y a aucune arène)
func _get_arena_gate_height(p: Vector2) -> float:
	var best_h: float = NAN
	var best_d: float = INF
	for zone in _arena_flat_zones:
		var d: float = p.distance_squared_to(zone.pos)
		if d < best_d:
			best_d = d
			best_h = zone.height
	return best_h


## Hauteur du sol HORS de la map (sous l'arène). À d=0 (bord de la map) : valeur exacte du Terrain3D, donc
## aucun raccord. Puis le sol rejoint en douceur (smoothstep) l'altitude de l'entrée de l'arène et reste
## parfaitement plat à cette altitude : pas de descente ni de montée dans l'arène.
func get_arena_ground_height(x: float, z: float) -> float:
	var rect: Rect2 = _get_map_rect()
	var dx: float = maxf(rect.position.x - x, x - rect.end.x)
	var dz: float = maxf(rect.position.y - z, z - rect.end.y)
	if dx <= 0.0 and dz <= 0.0:
		return _sample_edge_height(x, z)
	
	var inset: float = 0.5
	var ex: float = clampf(x, rect.position.x + inset, rect.end.x - inset)
	var ez: float = clampf(z, rect.position.y + inset, rect.end.y - inset)
	var edge_h: float = _sample_edge_height(ex, ez)
	
	var gate_h: float = _get_arena_gate_height(Vector2(x, z))
	if is_nan(gate_h):
		return edge_h
	
	var d_out: float = Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()
	var t: float = clampf(d_out / maxf(arena_ground_blend_distance, 0.01), 0.0, 1.0)
	return lerpf(edge_h, gate_h, t * t * (3.0 - 2.0 * t))


## Hauteur d'un sommet du maillage de sol. Sur la rangée qui recouvre le bord de la map, le maillage passe
## très légèrement SOUS le Terrain3D (jusqu'à -25 cm) pour éviter tout z-fighting et toute fissure.
func _arena_vertex_height(x: float, z: float, rect: Rect2, cell: float) -> float:
	var dx: float = maxf(rect.position.x - x, x - rect.end.x)
	var dz: float = maxf(rect.position.y - z, z - rect.end.y)
	if dx > 0.0001 or dz > 0.0001:
		return get_arena_ground_height(x, z)
	var depth: float = minf(minf(x - rect.position.x, rect.end.x - x), minf(z - rect.position.y, rect.end.y - z))
	return _sample_edge_height(x, z) - 0.25 * clampf(depth / cell, 0.0, 1.0)


func _cached_arena_height(cache: Dictionary, vi: int, vj: int, rect: Rect2, cell: float) -> float:
	var key := Vector2i(vi, vj)
	if cache.has(key):
		return cache[key]
	var h: float = _arena_vertex_height(float(vi) * cell, float(vj) * cell, rect, cell)
	cache[key] = h
	return h


func _polygon_area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


## Une cellule du sol existe si son centre est dans l'emprise de l'arène ET hors de la map
## (plus une seule rangée qui recouvre le bord de la map, cachée sous le Terrain3D)
func _is_arena_ground_cell(ci: int, cj: int, cell: float, rect: Rect2, poly: PackedVector2Array) -> bool:
	var center := Vector2((float(ci) + 0.5) * cell, (float(cj) + 0.5) * cell)
	if not Geometry2D.is_point_in_polygon(center, poly):
		return false
	if rect.has_point(center):
		var depth: float = minf(minf(center.x - rect.position.x, rect.end.x - center.x), minf(center.y - rect.position.y, rect.end.y - center.y))
		if depth >= cell:
			return false
	return true


## Emprise du sol d'une arène en coordonnées monde (courbe du mur d'arbres, élargie de 25 m
## pour passer largement sous et derrière les arbres). Vide si impossible à calculer.
func _get_arena_footprint(arena_inst: Node3D, zone: Dictionary, inflate: bool = true) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	if arena_inst == null:
		return poly
	var path_node: Path3D = null
	for child in arena_inst.find_children("*", "Path3D", true, false):
		if child is Path3D and child.curve != null:
			path_node = child
			break
	if path_node != null:
		var pts: PackedVector3Array = path_node.curve.tessellate_even_length(5, 3.0)
		for p in pts:
			var wp: Vector3 = path_node.global_transform * p
			poly.append(Vector2(wp.x, wp.z))
	else:
		var r: float = zone.get("flat_radius", 60.0)
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		for i in range(48):
			var a: float = TAU * float(i) / 48.0
			poly.append(center + Vector2(cos(a), sin(a)) * r)
	if poly.size() < 3:
		return PackedVector2Array()
	if not inflate:
		return poly
	
	var inflated = Geometry2D.offset_polygon(poly, 25.0, Geometry2D.JOIN_ROUND)
	if inflated.is_empty() or _polygon_area(inflated[0]) < _polygon_area(poly):
		inflated = Geometry2D.offset_polygon(poly, -25.0, Geometry2D.JOIN_ROUND)
	if inflated.is_empty():
		return PackedVector2Array()
	var ground_poly: PackedVector2Array = inflated[0]
	for pg in inflated:
		if _polygon_area(pg) > _polygon_area(ground_poly):
			ground_poly = pg
	return ground_poly


## Prolonge le VRAI Terrain3D sous l'arène : mêmes shader/textures/collisions que la map, donc aucune
## ligne de raccord visible. Les régions hors map sont remplies avec get_arena_ground_height().
## Retourne false si Terrain3D refuse (=> le maillage de secours _create_arena_ground est utilisé).
func _extend_terrain_under_arena(footprint: PackedVector2Array) -> bool:
	if footprint.size() < 3 or terrain == null:
		return false
	var terrain_data = null
	if "data" in terrain and terrain.data:
		terrain_data = terrain.data
	if terrain_data == null or not terrain_data.has_method("import_images") or not terrain_data.has_method("get_height"):
		return false
	
	var rs: int = region_size
	var rect: Rect2 = _get_map_rect()
	var bb_min := Vector2(INF, INF)
	var bb_max := Vector2(-INF, -INF)
	for v in footprint:
		bb_min = bb_min.min(v)
		bb_max = bb_max.max(v)
	var rx0: int = int(floor(bb_min.x / float(rs)))
	var rx1: int = int(floor(bb_max.x / float(rs)))
	var rz0: int = int(floor(bb_min.y / float(rs)))
	var rz1: int = int(floor(bb_max.y / float(rs)))
	
	for rx in range(rx0, rx1 + 1):
		for rz in range(rz0, rz1 + 1):
			var r_rect := Rect2(float(rx * rs), float(rz * rs), float(rs), float(rs))
			if rect.encloses(r_rect):
				continue # région de la vraie map : on n'y touche pas
			var key := Vector2i(rx, rz)
			if _outside_regions.has(key):
				continue
			_import_outside_region(terrain_data, rx, rz)
			_outside_regions[key] = true
	
	# Vérification : un sommet de l'emprise hors map doit renvoyer la hauteur attendue
	for v in footprint:
		if rect.has_point(v):
			continue
		var h: float = terrain_data.get_height(Vector3(v.x, 0.0, v.y))
		if is_nan(h) or absf(h - get_arena_ground_height(v.x, v.y)) > 1.0:
			push_warning("MapGenerator: Terrain3D n'a pas accepté la région hors map, utilisation du maillage de secours.")
			return false
		return true
	return true


## Remplit une région Terrain3D située (au moins en partie) hors de la map avec le sol d'arène.
func _import_outside_region(terrain_data, rx: int, rz: int) -> void:
	var rs: int = region_size
	var rect: Rect2 = _get_map_rect()
	var inset: float = 0.5
	var x0: int = rx * rs
	var z0: int = rz * rs
	
	var dx_arr := PackedFloat32Array()
	var dz_arr := PackedFloat32Array()
	var ex_arr := PackedFloat32Array()
	var ez_arr := PackedFloat32Array()
	dx_arr.resize(rs)
	dz_arr.resize(rs)
	ex_arr.resize(rs)
	ez_arr.resize(rs)
	var x_all_out: bool = true
	var z_all_out: bool = true
	for i in range(rs):
		var x: float = float(x0 + i)
		var z: float = float(z0 + i)
		var dx: float = maxf(rect.position.x - x, x - rect.end.x)
		var dz: float = maxf(rect.position.y - z, z - rect.end.y)
		dx_arr[i] = maxf(dx, 0.0)
		dz_arr[i] = maxf(dz, 0.0)
		ex_arr[i] = clampf(x, rect.position.x + inset, rect.end.x - inset)
		ez_arr[i] = clampf(z, rect.position.y + inset, rect.end.y - inset)
		if dx <= 0.0:
			x_all_out = false
		if dz <= 0.0:
			z_all_out = false
	
	# Profil de hauteur du bord de la map (ne dépend que d'une seule coordonnée par région hors map)
	var col_prof := PackedFloat32Array() # selon x (région hors map en z)
	var row_prof := PackedFloat32Array() # selon z (région hors map en x)
	var corner_h: float = 0.0
	if x_all_out and z_all_out:
		corner_h = _sample_edge_height(ex_arr[0], ez_arr[0])
	elif z_all_out:
		col_prof.resize(rs)
		for i in range(rs):
			col_prof[i] = _sample_edge_height(ex_arr[i], ez_arr[0])
	elif x_all_out:
		row_prof.resize(rs)
		for i in range(rs):
			row_prof[i] = _sample_edge_height(ex_arr[0], ez_arr[i])
	else:
		return
	
	var blend_dist: float = maxf(arena_ground_blend_distance, 0.01)
	var single_gate: bool = _arena_flat_zones.size() == 1
	var const_gate: float = _get_arena_gate_height(Vector2(float(x0), float(z0)))
	var has_gate: bool = not is_nan(const_gate)
	
	var heights := PackedFloat32Array()
	heights.resize(rs * rs)
	var idx: int = 0
	for pz in range(rs):
		var ddz: float = dz_arr[pz]
		for px in range(rs):
			var ddx: float = dx_arr[px]
			var edge_h: float
			if x_all_out and z_all_out:
				edge_h = corner_h
			elif z_all_out:
				edge_h = col_prof[px]
			else:
				edge_h = row_prof[pz]
			if not has_gate:
				heights[idx] = edge_h
			else:
				var gate_h: float = const_gate
				if not single_gate:
					gate_h = _get_arena_gate_height(Vector2(float(x0 + px), float(z0 + pz)))
				var t: float = clampf(sqrt(ddx * ddx + ddz * ddz) / blend_dist, 0.0, 1.0)
				heights[idx] = lerpf(edge_h, gate_h, t * t * (3.0 - 2.0 * t))
			idx += 1
	
	var ctrl_default: int = ((0 & 0x1F) << 27) | ((1 & 0x1F) << 22) | (1 << 1)
	var ctrl := PackedInt32Array()
	ctrl.resize(rs * rs)
	ctrl.fill(ctrl_default)
	
	var img: Image = Image.create_from_data(rs, rs, false, Image.FORMAT_RF, heights.to_byte_array())
	var control_img: Image = Image.create_from_data(rs, rs, false, Image.FORMAT_RF, ctrl.to_byte_array())
	terrain_data.import_images([img, control_img, null], Vector3(float(x0), 0.0, float(z0)), 0.0, 1.0)


## Crée un maillage de secours sous l'arène (hors de la scène boss_arena, qui reste intacte) :
## prolongement lisse du relief réel du bord de la map, raccordé sans coupure ni marche à l'entrée.
## Les arbres de l'arène utilisent get_terrain_height_at() => exactement la même hauteur que ce maillage.
func _create_arena_ground(arena_inst: Node3D, zone: Dictionary) -> void:
	if arena_inst == null:
		return
	
	var ground_name: String = "Arena_Ground_" + str(zone.get("name", "Arena")).trim_prefix("Arena_")
	var existing: Node = get_node_or_null(ground_name)
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	
	var ground_poly: PackedVector2Array = _get_arena_footprint(arena_inst, zone)
	if ground_poly.size() < 3:
		return
	
	# 3. Cellules retenues (grille alignée sur le repère monde => un alignement exact avec le bord de la map)
	var cell: float = maxf(arena_ground_cell_size, 1.0)
	var rect: Rect2 = _get_map_rect()
	var bb_min := Vector2(INF, INF)
	var bb_max := Vector2(-INF, -INF)
	for v in ground_poly:
		bb_min = bb_min.min(v)
		bb_max = bb_max.max(v)
	var ci0: int = int(floor(bb_min.x / cell))
	var ci1: int = int(ceil(bb_max.x / cell))
	var cj0: int = int(floor(bb_min.y / cell))
	var cj1: int = int(ceil(bb_max.y / cell))
	
	var kept: Dictionary = {}
	for ci in range(ci0, ci1):
		for cj in range(cj0, cj1):
			if _is_arena_ground_cell(ci, cj, cell, rect, ground_poly):
				kept[Vector2i(ci, cj)] = true
	if kept.is_empty():
		push_warning("MapGenerator: aucune cellule de sol d'arène générée.")
		return
	
	# 4. Maillage : face supérieure (hauteur lissée + normales lissées) + jupe périphérique
	var hcache: Dictionary = {}
	var uv_scale: float = 0.08
	var skirt: float = maxf(arena_ground_skirt_depth, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var corner_offsets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
	# [décalage voisin, indice coin A, indice coin B, normale sortante]
	var sides: Array = [
		[Vector2i(0, -1), 0, 1, Vector3(0, 0, -1)],
		[Vector2i(1, 0), 1, 2, Vector3(1, 0, 0)],
		[Vector2i(0, 1), 3, 2, Vector3(0, 0, 1)],
		[Vector2i(-1, 0), 0, 3, Vector3(-1, 0, 0)],
	]
	
	var triangle_count: int = 0
	for key in kept.keys():
		var ci: int = key.x
		var cj: int = key.y
		var corners: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for o in corner_offsets:
			var vi: int = ci + o.x
			var vj: int = cj + o.y
			var h: float = _cached_arena_height(hcache, vi, vj, rect, cell)
			var hx: float = _cached_arena_height(hcache, vi + 1, vj, rect, cell) - _cached_arena_height(hcache, vi - 1, vj, rect, cell)
			var hz: float = _cached_arena_height(hcache, vi, vj + 1, rect, cell) - _cached_arena_height(hcache, vi, vj - 1, rect, cell)
			corners.append(Vector3(float(vi) * cell, h, float(vj) * cell))
			normals.append(Vector3(-hx, 2.0 * cell, -hz).normalized())
		
		# Sens horaire vu du dessus = face avant dans Godot
		for idx in [0, 1, 2, 0, 2, 3]:
			var cp: Vector3 = corners[idx]
			st.set_normal(normals[idx])
			st.set_uv(Vector2(cp.x, cp.z) * uv_scale)
			st.add_vertex(cp)
		triangle_count += 2
		
		if skirt <= 0.0:
			continue
		for s in sides:
			var nb: Vector2i = Vector2i(ci, cj) + (s[0] as Vector2i)
			if kept.has(nb):
				continue
			# Pas de jupe du côté de la map : le sol s'y glisse sous le Terrain3D
			var nb_center := Vector2((float(nb.x) + 0.5) * cell, (float(nb.y) + 0.5) * cell)
			if rect.has_point(nb_center):
				continue
			var top_a: Vector3 = corners[s[1]]
			var top_b: Vector3 = corners[s[2]]
			var bot_a: Vector3 = top_a - Vector3(0.0, skirt, 0.0)
			var bot_b: Vector3 = top_b - Vector3(0.0, skirt, 0.0)
			for sp in [top_a, top_b, bot_a, top_b, bot_b, bot_a]:
				st.set_normal(s[3])
				st.set_uv(Vector2(sp.x, sp.z) * uv_scale)
				st.add_vertex(sp)
			triangle_count += 2
	
	var mesh: ArrayMesh = st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	
	# 5. Matériau : même herbe que le Terrain3D (triplanaire monde), visible dessus ET dessous
	var mat := StandardMaterial3D.new()
	var alb_tex = load("res://assets/texture/grass_05/Grass005_alb_ht.dds")
	var nrm_tex = load("res://assets/texture/grass_05/Grass005_nrm_rgh.dds")
	if alb_tex != null:
		mat.albedo_texture = alb_tex
	else:
		mat.albedo_color = Color(0.22, 0.35, 0.15)
	if nrm_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = nrm_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	
	var ground_body := StaticBody3D.new()
	ground_body.name = ground_name
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "GroundMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_body.add_child(mesh_inst)
	
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	var col_shape := CollisionShape3D.new()
	col_shape.name = "GroundCollision"
	col_shape.shape = shape
	ground_body.add_child(col_shape)
	
	add_child(ground_body)
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		ground_body.owner = get_tree().edited_scene_root
		mesh_inst.owner = get_tree().edited_scene_root
		col_shape.owner = get_tree().edited_scene_root
	
	print("MapGenerator: Sol d'arène '%s' généré (%d cellules, %d triangles, plat à %.2f m après %.0f m)." % [
		ground_name, kept.size(), triangle_count, float(zone.get("height", 0.0)), arena_ground_blend_distance
	])
