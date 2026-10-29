@tool
class_name ArenaGenerator
extends Node3D

## Composant enfant du MapGenerator qui gère les arènes de boss aux sorties de la carte.
## Chaque slot (Nord / Ouest / Est) contient une liste de scènes d'arène : au début de la génération,
## UNE scène est tirée au hasard par slot (déterministe d'après la seed du monde) et instanciée
## à la sortie correspondante. Un slot vide = pas d'arène : la sortie reste fermée par le mur d'arbres.
##
## Exigences sur chaque scène d'arène (sinon erreur explicite, l'arène est ignorée) :
## - un Marker3D nommé « entry » (aligné sur le trou dans le mur d'arbres),
## - un Path3D (courbe du mur d'arbres) qui définit l'emprise de l'arène.

const SLOT_NORTH: int = 0
const SLOT_WEST: int = 1
const SLOT_EAST: int = 2
const SLOT_NAMES: Array[String] = ["Arena_North", "Arena_West", "Arena_East"]

## Marge de sécurité ajoutée à l'emprise de la courbe pour définir le rayon de sol plat (en mètres)
const ARENA_SAFETY_MARGIN: float = 40.0
## Rayon de raccordement autour du sol plat d'une arène (en mètres)
const ARENA_BLEND_RADIUS: float = 45.0
## Élargissement de l'emprise du sol sous l'arène pour passer largement sous et derrière les arbres (en mètres)
const ARENA_GROUND_INFLATE: float = 25.0
## Distance min. au bord de la map pour échantillonner Terrain3D : get_height() renvoie NaN en interpolant sur la dernière rangée de pixels
const EDGE_SAMPLE_INSET: float = 1.5

@export_category("Slots d'arènes")
## Arènes possibles à la sortie NORD (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var north_arenas: Array[PackedScene] = []
## Arènes possibles à la sortie OUEST (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var west_arenas: Array[PackedScene] = []
## Arènes possibles à la sortie EST (une est tirée au hasard à chaque génération). Vide = pas d'arène.
@export var east_arenas: Array[PackedScene] = []

@export_category("Boss d'Arène")
## Liste des scènes de Boss possibles à faire apparaître dans l'arène de boss (tirage aléatoire déterministe avec la world_seed)
@export var possible_bosses: Array[PackedScene] = [
	preload("res://character/enemie/ogre_boss/ogre_boss.tscn")
]

@export_category("Sol d'arène")
## Distance (depuis le bord de la map) sur laquelle le sol passe du relief réel du bord à l'altitude de l'entrée
## de l'arène, puis reste parfaitement plat. Plus c'est grand, plus les pentes sur les côtés sont douces.
@export var arena_ground_blend_distance: float = 90.0

var _arena_flat_zones: Array[Dictionary] = []
## Régions Terrain3D (indices) ajoutées hors de la map pour prolonger le sol sous les arènes
var _outside_regions: Dictionary = {}
## Contours (coordonnées monde XZ) de l'intérieur des arènes : GrassGenerator y plante aussi de l'herbe
var arena_grass_polygons: Array[PackedVector2Array] = []
## Scène choisie pour chaque slot (clé = SLOT_*), remplie par select_arenas()
var _selected_scenes: Dictionary = {}
## Scène de boss choisie pour chaque slot (clé = SLOT_*), remplie par select_arenas()
var _selected_bosses: Dictionary = {}
var _selection_done: bool = false
var _edge_height_error_reported: bool = false

# --- Accès aux réglages du MapGenerator parent (le parent DOIT être le MapGenerator) ---
var map_generator: Node3D:
	get: return get_parent() as Node3D
var terrain: Terrain3D:
	get: return map_generator.get("terrain")
var path_generator: Node:
	get: return map_generator.get("path_generator")
var region_size: int:
	get: return int(map_generator.get("region_size"))
var map_width_chunks: int:
	get: return int(map_generator.get("map_width_chunks"))
var map_height_chunks: int:
	get: return int(map_generator.get("map_height_chunks"))
var border_margin: float:
	get: return float(map_generator.get("border_margin"))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_parent() == null or not get_parent().has_method("get_arena_generator"):
		warnings.append("ArenaGenerator doit être un enfant direct du MapGenerator.")
	return warnings


func _get_map_rect() -> Rect2:
	return map_generator._get_map_rect()


## Hauteur réelle du Terrain3D (NaN = pas de donnée : erreur signalée une seule fois par génération)
func _sample_edge_height(x: float, z: float) -> float:
	var h: float = map_generator._sample_edge_height(x, z)
	if is_nan(h) and not _edge_height_error_reported:
		_edge_height_error_reported = true
		push_error("ArenaGenerator: hauteur de Terrain3D introuvable en (%.1f, %.1f) : le terrain de la map n'est pas généré." % [x, z])
	return h


# --- Sélection des arènes ---

## Tire au hasard UNE arène par slot (déterministe d'après la seed). À appeler au début de la génération,
## avant la génération des routes (les sorties dépendent des slots actifs).
func select_arenas(seed_value: int) -> void:
	_selected_scenes.clear()
	_selected_bosses.clear()
	_edge_height_error_reported = false
	
	var valid_bosses: Array[PackedScene] = []
	for b_scn in possible_bosses:
		if b_scn != null:
			valid_bosses.append(b_scn)
			
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
		
		if not valid_bosses.is_empty():
			var boss_rng := RandomNumberGenerator.new()
			boss_rng.seed = hash([seed_value, loc, "arena_boss"])
			_selected_bosses[loc] = valid_bosses[boss_rng.randi_range(0, valid_bosses.size() - 1)]
			print("ArenaGenerator: slot %s => boss sélectionné : %s" % [SLOT_NAMES[loc], _selected_bosses[loc].resource_path])
	_selection_done = true


## Vrai si le slot (SLOT_NORTH / WEST / EAST) a une arène sélectionnée.
## select_arenas() doit avoir été appelé avant.
func is_slot_active(location: int) -> bool:
	if not _selection_done:
		push_error("ArenaGenerator: select_arenas() doit être appelé avant is_slot_active().")
		return false
	return _selected_scenes.has(location)


func get_zones() -> Array[Dictionary]:
	return _arena_flat_zones


## Supprime les arènes générées et leurs données. Les régions Terrain3D ajoutées hors de la map sont
## retirées par MapGenerator.clear_terrain() (qui efface toutes les régions).
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
	_outside_regions.clear()


## Position du trou dans le mur d'arbres pour un slot (Vector2.ZERO + erreur si la sortie n'existe pas)
func _resolve_arena_position(location: int) -> Vector2:
	var b_margin: float = border_margin
	var map_w: float = float(map_width_chunks * region_size)
	var map_h: float = float(map_height_chunks * region_size)
	var exit_pos: Vector2 = Vector2.ZERO
	match location:
		SLOT_NORTH: # trou dans le mur Nord à Z = b_margin
			exit_pos = path_generator.exit_north
			if exit_pos != Vector2.ZERO:
				return Vector2(exit_pos.x, b_margin)
		SLOT_WEST: # trou dans le mur Ouest à X = b_margin
			exit_pos = path_generator.exit_west
			if exit_pos != Vector2.ZERO:
				return Vector2(b_margin, exit_pos.y)
		SLOT_EAST: # trou dans le mur Est à X = map_w - b_margin
			exit_pos = path_generator.exit_east
			if exit_pos != Vector2.ZERO:
				return Vector2(map_w - b_margin, exit_pos.y)
	push_error("ArenaGenerator: sortie introuvable pour le slot %s (le chemin n'a pas été généré ?)." % SLOT_NAMES[location])
	return Vector2.ZERO


## Direction vers l'extérieur de la map pour un slot
func _resolve_arena_direction(location: int) -> Vector2:
	match location:
		SLOT_NORTH: return Vector2(0, -1)
		SLOT_WEST: return Vector2(-1, 0)
		_: return Vector2(1, 0)


## Premier Path3D (avec courbe) d'une scène d'arène, null + erreur s'il n'y en a pas
func _find_arena_path(arena_inst: Node, arena_name: String) -> Path3D:
	for child in arena_inst.find_children("*", "Path3D", true, false):
		if child is Path3D and child.curve != null:
			return child
	push_error("ArenaGenerator: l'arène '%s' n'a aucun Path3D avec une courbe (emprise de l'arène)." % arena_name)
	return null


## Analyse géométrique de la courbe (Path3D) d'une scène d'arène.
## Calcule le centre réel et l'emprise maximale par rapport au Marker3D 'entry'. Dictionnaire vide en cas d'erreur.
func _get_arena_curve_geometry(arena_scene: PackedScene, arena_name: String) -> Dictionary:
	var inst: Node = arena_scene.instantiate()
	var entry_node: Node3D = inst.find_child("entry", true, false) as Node3D
	if entry_node == null:
		push_error("ArenaGenerator: l'arène '%s' n'a pas de Marker3D nommé « entry »." % arena_name)
		inst.free()
		return {}
	var path_node: Path3D = _find_arena_path(inst, arena_name)
	if path_node == null:
		inst.free()
		return {}
	
	var entry_pos: Vector3 = entry_node.position
	var rel_t: Transform3D = Transform3D.IDENTITY
	var curr: Node = path_node
	while curr != null and curr != inst:
		if curr is Node3D:
			rel_t = curr.transform * rel_t
		curr = curr.get_parent()
	
	var points_local: Array[Vector2] = []
	for pt in path_node.curve.get_baked_points():
		var p_scene: Vector3 = rel_t * pt - entry_pos
		points_local.append(Vector2(p_scene.x, p_scene.z))
	inst.free()
	
	if points_local.is_empty():
		push_error("ArenaGenerator: la courbe de l'arène '%s' ne contient aucun point." % arena_name)
		return {}
	
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for pt in points_local:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
		min_z = minf(min_z, pt.y)
		max_z = maxf(max_z, pt.y)
	
	var local_center := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	var max_dist: float = 0.0
	for pt in points_local:
		max_dist = maxf(max_dist, pt.distance_to(local_center))
	var half_diag: float = Vector2((max_x - min_x) * 0.5, (max_z - min_z) * 0.5).length()
	var base_radius: float = maxf(max_dist, half_diag)
	
	return {
		"local_center": local_center,
		"radius": base_radius,
		"flat_radius": base_radius + ARENA_SAFETY_MARGIN,
		"blend_radius": ARENA_BLEND_RADIUS
	}


## Initialise les zones de sol plat pour toutes les arènes actives.
## L'altitude de chaque zone est définie dans spawn_arenas() à partir du vrai Terrain3D.
func init_zones() -> void:
	_arena_flat_zones.clear()
	
	for loc in [SLOT_NORTH, SLOT_WEST, SLOT_EAST]:
		if not _selected_scenes.has(loc):
			continue
		var arena_name: String = SLOT_NAMES[loc]
		var scene: PackedScene = _selected_scenes[loc]
		
		var hole_pos: Vector2 = _resolve_arena_position(loc)
		if hole_pos == Vector2.ZERO:
			continue
		var dir: Vector2 = _resolve_arena_direction(loc)
		
		var geom: Dictionary = _get_arena_curve_geometry(scene, arena_name)
		if geom.is_empty():
			continue
		
		# Orientation 3D pour projeter le centre local de la courbe dans le monde
		var forward_3d := Vector3(dir.x, 0.0, dir.y)
		var arena_basis: Basis = Basis.looking_at(forward_3d, Vector3.UP)
		var local_c: Vector2 = geom["local_center"]
		var offset_3d: Vector3 = arena_basis * Vector3(local_c.x, 0.0, local_c.y)
		var center: Vector2 = hole_pos + Vector2(offset_3d.x, offset_3d.z)
		
		var flat_r: float = geom["flat_radius"]
		var blend_r: float = geom["blend_radius"]
		var total_r: float = flat_r + blend_r
		
		var zone: Dictionary = {
			"slot": loc,
			"name": arena_name,
			"scene": scene,
			"pos": hole_pos,
			"dir": dir,
			"center": center,
			"height": NAN,
			"flat_radius": flat_r,
			"blend_radius": blend_r,
			"total_radius": total_r,
			"min_x": center.x - total_r,
			"max_x": center.x + total_r,
			"min_z": center.y - total_r,
			"max_z": center.y + total_r
		}
		_arena_flat_zones.append(zone)
		
		print("Arène '%s': Sol plat adapté à la courbe au centre %v (rayon_plat=%.1fm, blend=%.1fm, Trou=%v)." % [
			zone.name, zone.center, zone.flat_radius, zone.blend_radius, zone.pos
		])


## Instancie et configure toutes les arènes sur la carte (init_zones() doit avoir été appelé)
func spawn_arenas() -> void:
	if _arena_flat_zones.is_empty():
		print("ArenaGenerator: aucune arène à générer.")
		return
	
	arena_grass_polygons.clear()
	var mesh_spawner: Node = map_generator.get_node("MeshSpawner")
	var border_wall: Node = map_generator.get_node("BorderTreeWall")
	
	# Altitude de chaque entrée d'arène (relief réel du bord de la map), connue avant de remplir les sols
	for z in _arena_flat_zones:
		z["height"] = _sample_edge_height(z.pos.x, z.pos.y)
	
	for zone in _arena_flat_zones:
		var ground_y: float = zone["height"]
		if is_nan(ground_y):
			push_error("ArenaGenerator: arène '%s' ignorée (altitude de l'entrée introuvable)." % zone["name"])
			continue
		
		var scn: PackedScene = zone["scene"]
		var arena_inst: Node3D = scn.instantiate() as Node3D
		if arena_inst == null:
			push_error("ArenaGenerator: la scène de l'arène '%s' n'a pas de racine Node3D." % zone["name"])
			continue
		var entry_marker: Node3D = arena_inst.find_child("entry", true, false) as Node3D
		if entry_marker == null:
			push_error("ArenaGenerator: l'arène '%s' n'a pas de Marker3D nommé « entry »." % zone["name"])
			arena_inst.free()
			continue
			
		arena_inst.name = zone["name"]
		arena_inst.add_to_group("BossArena")
		
		# Injecter la scène de boss tirée avec la world_seed et le fournisseur de hauteur du sol
		var slot_idx: int = int(zone.get("slot", -1))
		if "boss_scene" in arena_inst and _selected_bosses.has(slot_idx):
			arena_inst.set("boss_scene", _selected_bosses[slot_idx])
		if "height_provider" in arena_inst:
			arena_inst.set("height_provider", Callable(map_generator, "get_terrain_height_at"))
		
		# 1. Orientation vers l'extérieur (hors de la carte)
		arena_inst.transform.basis = Basis.looking_at(Vector3(zone.dir.x, 0.0, zone.dir.y), Vector3.UP)
			
		# 2. Positionnement : aligner le Marker3D 'entry' exactement sur le milieu du trou dans les arbres
		var hole_pos_3d := Vector3(zone.pos.x, ground_y, zone.pos.y)
		arena_inst.position = hole_pos_3d - arena_inst.basis * entry_marker.position
		
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
		
		# 3. Sol sous l'arène : prolongement du vrai Terrain3D (même shader => aucune ligne de raccord)
		var footprint: PackedVector2Array = _get_arena_footprint(arena_inst, true)
		var inner_poly: PackedVector2Array = _get_arena_footprint(arena_inst, false)
		if footprint.is_empty() or inner_poly.is_empty():
			push_error("ArenaGenerator: emprise de l'arène '%s' introuvable, aucun sol généré." % zone["name"])
			continue
		arena_grass_polygons.append(inner_poly)
		if not _extend_terrain_under_arena(footprint):
			push_error("ArenaGenerator: le Terrain3D n'a pas pu être prolongé sous l'arène '%s'." % zone["name"])
		
		# Ordonner explicitement à chaque MarkerTreeSpawnerComponent de générer les arbres maintenant que le terrain plat est prêt
		for spawner in tree_spawners:
			spawner.height_provider = Callable(map_generator, "get_terrain_height_at")
			# Synchroniser l'échelle des arbres de l'arène avec les arbres géants du mur de frontière
			spawner.min_scale = border_wall.min_scale
			spawner.max_scale = border_wall.max_scale
			spawner.spawn_trees()
			
		# Si c'est une arène d'enchantement (EnchantArena), faire apparaître son totem maintenant que le sol Terrain3D sous l'arène est généré
		if arena_inst.has_method("spawn_totem"):
			arena_inst.spawn_totem()
			
		# Nettoyer les arbres de forêt MeshSpawner à proximité du centre de l'arène
		var arena_center_3d := Vector3(zone.center.x, ground_y, zone.center.y)
		mesh_spawner.clear_trees_in_radius(arena_center_3d, zone.flat_radius + 5.0)
			
		print("MapGenerator: Arène '%s' générée (Orientation: %v) avec 'entry' aligné à %v (Trou: %v)." % [
			arena_inst.name, arena_inst.rotation_degrees, entry_marker.global_position, hole_pos_3d
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
## Sans arène (ou avant que l'altitude de son entrée soit connue), le sol prolonge simplement la hauteur du bord.
func get_arena_ground_height(x: float, z: float) -> float:
	var rect: Rect2 = _get_map_rect()
	var inset: float = EDGE_SAMPLE_INSET
	var dx: float = maxf(rect.position.x - x, x - rect.end.x)
	var dz: float = maxf(rect.position.y - z, z - rect.end.y)
	if x >= rect.position.x + inset and x <= rect.end.x - inset and z >= rect.position.y + inset and z <= rect.end.y - inset:
		return _sample_edge_height(x, z)
	
	var ex: float = clampf(x, rect.position.x + inset, rect.end.x - inset)
	var ez: float = clampf(z, rect.position.y + inset, rect.end.y - inset)
	var edge_h: float = _sample_edge_height(ex, ez)
	
	var gate_h: float = _get_arena_gate_height(Vector2(x, z))
	if is_nan(gate_h):
		return edge_h
	
	var d_out: float = Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()
	var t: float = clampf(d_out / maxf(arena_ground_blend_distance, 0.01), 0.0, 1.0)
	return lerpf(edge_h, gate_h, t * t * (3.0 - 2.0 * t))


func _polygon_area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


## Emprise du sol d'une arène en coordonnées monde (courbe Path3D du mur d'arbres), élargie de
## ARENA_GROUND_INFLATE mètres si `inflate` pour passer largement sous et derrière les arbres.
## Polygone vide (+ erreur) si impossible à calculer.
func _get_arena_footprint(arena_inst: Node3D, inflate: bool) -> PackedVector2Array:
	var path_node: Path3D = _find_arena_path(arena_inst, arena_inst.name)
	if path_node == null:
		return PackedVector2Array()
	
	var poly: PackedVector2Array = PackedVector2Array()
	for p in path_node.curve.tessellate_even_length(5, 3.0):
		var wp: Vector3 = path_node.global_transform * p
		poly.append(Vector2(wp.x, wp.z))
	if poly.size() < 3:
		push_error("ArenaGenerator: la courbe de l'arène '%s' est trop courte pour définir une emprise." % arena_inst.name)
		return PackedVector2Array()
	if not inflate:
		return poly
	
	var inflated: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, ARENA_GROUND_INFLATE, Geometry2D.JOIN_ROUND)
	if inflated.is_empty():
		push_error("ArenaGenerator: l'élargissement de l'emprise de l'arène '%s' a échoué." % arena_inst.name)
		return PackedVector2Array()
	var ground_poly: PackedVector2Array = inflated[0]
	for pg in inflated:
		if _polygon_area(pg) > _polygon_area(ground_poly):
			ground_poly = pg
	return ground_poly


## Prolonge le VRAI Terrain3D sous l'arène : mêmes shader/textures/collisions que la map, donc aucune
## ligne de raccord visible. Les régions hors map sont remplies avec get_arena_ground_height().
## Retourne false (+ erreur) si Terrain3D refuse la région : il n'y a pas de sol de remplacement.
func _extend_terrain_under_arena(footprint: PackedVector2Array) -> bool:
	var terrain_data: Terrain3DData = terrain.data
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
			push_error("ArenaGenerator: Terrain3D n'a pas accepté la région hors map (hauteur %.2f au lieu de %.2f en %v)." % [h, get_arena_ground_height(v.x, v.y), v])
			return false
		return true
	return true


## Remplit une région Terrain3D située (au moins en partie) hors de la map avec le sol d'arène.
func _import_outside_region(terrain_data: Terrain3DData, rx: int, rz: int) -> void:
	var rs: int = region_size
	var rect: Rect2 = _get_map_rect()
	var inset: float = EDGE_SAMPLE_INSET
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
	var x_all_out: bool = (rx < 0 or rx >= map_width_chunks)
	var z_all_out: bool = (rz < 0 or rz >= map_height_chunks)
	for i in range(rs):
		var x: float = float(x0 + i)
		var z: float = float(z0 + i)
		var dx: float = maxf(rect.position.x - x, x - rect.end.x)
		var dz: float = maxf(rect.position.y - z, z - rect.end.y)
		dx_arr[i] = maxf(dx, 0.0)
		dz_arr[i] = maxf(dz, 0.0)
		ex_arr[i] = clampf(x, rect.position.x + inset, rect.end.x - inset)
		ez_arr[i] = clampf(z, rect.position.y + inset, rect.end.y - inset)
	
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
		push_error("ArenaGenerator: la région (%d, %d) chevauche la map, elle ne peut pas servir de sol d'arène." % [rx, rz])
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
