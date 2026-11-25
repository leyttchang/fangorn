@tool
class_name RoadForestPropSpawner
extends Node3D

## Spawner procédural dédié à 1 type de prop forestier (Champignon, Cocon, Catapulte).
## Place les instances de façon déterministe autour des arbres et aux abords de la route,
## contrôlé directement par un slider de fréquence (0.0 -> 1.0).

enum PlacementStyle {
	ROADSIDE_AND_TREES,    ## Abords immédiats de la route + pied des arbres proches (idéal Champignons)
	AROUND_TREES_PRIORITY, ## Collé en priorité au pied des arbres proches des chemins (idéal Cocons)
	ROADSIDE_CLEAR_LAUNCH  ## Abords dégagés de la route sans tronc au-dessus (idéal Racines-Catapultes)
}

@export_category("Prop & Fréquence de Spawn")
## Scène du prop à instancier (ex: speed_mushroom.tscn, root_cocoon.tscn, root_launcher.tscn)
@export var prop_scene: PackedScene

## Slider principal de fréquence de spawn (0.0 = désactivé, 1.0 = densité maximale)
@export_range(0.0, 1.0, 0.01) var spawn_frequency: float = 0.45:
	set(value):
		spawn_frequency = clampf(value, 0.0, 1.0)
		if Engine.is_editor_hint() and is_inside_tree() and live_update_in_editor:
			_schedule_editor_respawn()

## Nombre maximal d'instances lorsque le slider spawn_frequency est à 1.0 (pour 1 chunk 1024x1024, mis à l'échelle si plus de chunks)
@export_range(1, 600, 1) var max_count_at_full_frequency: int = 120

## Style de placement par rapport aux routes et aux arbres
@export var placement_style: PlacementStyle = PlacementStyle.ROADSIDE_AND_TREES

@export_category("Distances Route & Arbres")
## Proportion (0.0 à 1.0) d'instances ancrées au pied d'un arbre plutôt que sur le bord herbeux du chemin
@export_range(0.0, 1.0, 0.05) var tree_anchor_ratio: float = 0.45

## Distance minimale depuis le bord de la route (en mètres, 0 = juste à la lisière du chemin)
@export var road_edge_min_offset: float = 0.8
## Distance maximale depuis le bord de la route pour les spawns de bord de chemin (en mètres)
@export var road_edge_max_offset: float = 6.5
## Distance maximale depuis la route pour choisir un arbre hôte (en mètres)
@export var max_tree_distance_from_road: float = 42.0

## Espacement minimal entre deux instances de ce même prop (en mètres)
@export var min_spacing_between_props: float = 14.0
## Marge minimale par rapport aux troncs d'arbres (en mètres au-delà du rayon du tronc)
@export var tree_trunk_clearance: float = 0.65
## Rayon d'exclusion autour des Encounters / Villages / Cages (en mètres)
@export var encounter_exclusion_radius: float = 32.0
## Pente maximale tolérée au sol (en degrés)
@export_range(5.0, 65.0, 1.0) var max_slope_degrees: float = 34.0

@export_category("Variation Visuelle & Graine")
@export var min_scale: float = 0.90
@export var max_scale: float = 1.18
@export var align_to_ground_normal: bool = true
@export_range(0.0, 1.0, 0.05) var ground_tilt_strength: float = 0.35
@export var ground_sink_offset: float = -0.03
## Décalage de graine unique pour que chaque node spawner ait des positions différentes
@export var seed_offset: int = 4101

@export_category("Actions (Éditeur)")
## Met à jour automatiquement les props dans la scène quand on bouge le slider spawn_frequency
@export var live_update_in_editor: bool = true

@export var spawn_now: bool = false:
	set(value):
		spawn_now = false
		if value and is_inside_tree():
			generate_props(0)

@export var clear_now: bool = false:
	set(value):
		clear_now = false
		if value:
			clear_props()

var _editor_respawn_timer: float = -1.0

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _editor_respawn_timer > 0.0:
		_editor_respawn_timer -= delta
		if _editor_respawn_timer <= 0.0:
			_editor_respawn_timer = -1.0
			generate_props(0)

func _schedule_editor_respawn() -> void:
	_editor_respawn_timer = 0.22

## Supprime immédiatement tous les props enfants (remove_child + queue_free pour éviter tout renommage réseau Prop_0 -> @Node3D)
func clear_props() -> void:
	var children_copy := get_children()
	for child in children_copy:
		remove_child(child)
		child.queue_free()

func generate_props(custom_seed: int = 0) -> void:
	clear_props()

	if prop_scene == null or spawn_frequency <= 0.001:
		return

	var map_gen := _find_map_generator()
	if map_gen == null:
		push_warning("[RoadForestPropSpawner] '" + name + "' : MapGenerator parent introuvable.")
		return

	var terrain: Terrain3D = map_gen.get("terrain") as Terrain3D
	var path_gen: PathGenerator = map_gen.get("path_generator") as PathGenerator
	var mesh_spawner: Node = map_gen.get_node_or_null("MeshSpawner")

	if terrain == null or terrain.data == null:
		push_warning("[RoadForestPropSpawner] '" + name + "' : Terrain3D non prêt.")
		return
	if path_gen == null:
		push_warning("[RoadForestPropSpawner] '" + name + "' : PathGenerator manquant.")
		return

	# Résolution de la graine déterministe (identique Serveur & Client)
	var base_seed: int = custom_seed
	if base_seed == 0:
		if not Engine.is_editor_hint() and GameData.current_seed != 0:
			base_seed = GameData.current_seed
		elif "world_seed" in map_gen:
			base_seed = int(map_gen.world_seed)

	var map_w: float = float(map_gen.map_width_chunks * map_gen.region_size) if "map_width_chunks" in map_gen else 1024.0
	var map_h: float = float(map_gen.map_height_chunks * map_gen.region_size) if "map_height_chunks" in map_gen else 1024.0

	if path_gen.segments.is_empty():
		if Engine.is_editor_hint():
			if map_gen.has_method("get_arena_generator") and map_gen.get_arena_generator() != null:
				map_gen.get_arena_generator().select_arenas(base_seed)
			path_gen.generate_branching_path(0.0, map_w, 0.0, map_h, base_seed)
		else:
			push_warning("[RoadForestPropSpawner] '" + name + "' : PathGenerator vide.")
			return

	var terrain_data: Terrain3DData = terrain.data
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed + seed_offset

	# Adaptation au nombre de chunks de la carte
	var chunk_mult := 1.0
	if "map_width_chunks" in map_gen and "map_height_chunks" in map_gen:
		chunk_mult = maxf(1.0, float(map_gen.map_width_chunks * map_gen.map_height_chunks))

	var target_count := int(round(float(max_count_at_full_frequency) * spawn_frequency * chunk_mult))
	if target_count <= 0:
		return

	var b_margin: float = float(map_gen.border_margin) + 12.0 if "border_margin" in map_gen else 47.0

	# Récupération des arbres générés par MeshSpawner (ou fallback depuis les MultiMesh existants en éditeur)
	var all_trees: Array = []
	if mesh_spawner != null:
		if "spawned_tree_instances" in mesh_spawner and not mesh_spawner.spawned_tree_instances.is_empty():
			all_trees = mesh_spawner.spawned_tree_instances
		else:
			for child in mesh_spawner.get_children():
				if child is MultiMeshInstance3D and child.multimesh != null:
					var mm: MultiMesh = child.multimesh
					for i in range(mm.instance_count):
						var xf: Transform3D = mm.get_instance_transform(i)
						var approx_scale: float = xf.basis.x.length()
						all_trees.append({
							"pos": xf.origin,
							"trunk_pos": xf.origin,
							"trunk_radius": maxf(0.8, approx_scale * 0.16)
						})

	var tree_cell_size := 32.0
	var tree_grid: Dictionary = {}
	var roadside_trees: Array[Dictionary] = []

	for t_info in all_trees:
		var t_pos: Vector3 = t_info["trunk_pos"]
		var cell := Vector2i(int(floor(t_pos.x / tree_cell_size)), int(floor(t_pos.z / tree_cell_size)))
		if not tree_grid.has(cell):
			tree_grid[cell] = []
		tree_grid[cell].append(t_info)

		# Pré-sélection des arbres proches de la route pour un placement naturel en lisière !
		var p2 := Vector2(t_pos.x, t_pos.z)
		if p2.x > b_margin and p2.x < map_w - b_margin and p2.y > b_margin and p2.y < map_h - b_margin:
			if path_gen.is_point_on_path(p2, max_tree_distance_from_road):
				roadside_trees.append(t_info)

	var encounter_positions: Array = path_gen.encounter_positions
	var lesser_stele_pts: Array = map_gen.lesser_stele_positions if "lesser_stele_positions" in map_gen else []
	var spawn_start_2d: Vector2 = path_gen.start_pos
	var arena_zones: Array = map_gen.get_arena_zones() if map_gen.has_method("get_arena_zones") else []
	var segments: Array = path_gen.segments

	var slope_limit := tan(deg_to_rad(clampf(max_slope_degrees, 5.0, 75.0)))
	var min_spacing_sq := min_spacing_between_props * min_spacing_between_props
	var placed_positions_2d: Array[Vector2] = []

	var effective_tree_ratio := tree_anchor_ratio
	if placement_style == PlacementStyle.AROUND_TREES_PRIORITY:
		effective_tree_ratio = maxf(0.75, tree_anchor_ratio)
	elif placement_style == PlacementStyle.ROADSIDE_CLEAR_LAUNCH:
		effective_tree_ratio = 0.0

	var max_attempts := maxi(target_count * 18, 120)
	var attempts := 0
	var spawned_count := 0

	while spawned_count < target_count and attempts < max_attempts:
		attempts += 1

		var candidate_2d := Vector2.ZERO
		var facing_angle := rng.randf_range(0.0, TAU)
		var use_tree_anchor := (not roadside_trees.is_empty()) and (rng.randf() < effective_tree_ratio)

		if use_tree_anchor:
			# --- MODE A : AUTOUR D'UN ARBRE DES ABORDS DE LA ROUTE ---
			var host_tree: Dictionary = roadside_trees[rng.randi_range(0, roadside_trees.size() - 1)]
			var trunk_pos: Vector3 = host_tree["trunk_pos"]
			var trunk_r: float = float(host_tree["trunk_radius"])
			var ang := rng.randf_range(0.0, TAU)
			var dist_from_trunk := trunk_r + tree_trunk_clearance + rng.randf_range(0.15, 1.35)
			candidate_2d = Vector2(trunk_pos.x + cos(ang) * dist_from_trunk, trunk_pos.z + sin(ang) * dist_from_trunk)
			# Oriente le prop dos au tronc vers l'extérieur
			facing_angle = atan2(cos(ang), sin(ang))
		else:
			# --- MODE B : AUX ABORDS DE LA ROUTE (LISIÈRE DU CHEMIN) ---
			var seg: Dictionary = segments[rng.randi_range(0, segments.size() - 1)]
			var a: Vector2 = seg["start"]
			var b: Vector2 = seg["end"]
			var seg_vec := b - a
			var seg_len := seg_vec.length()
			if seg_len < 0.5:
				continue
			var dir := seg_vec / seg_len
			var perp := Vector2(-dir.y, dir.x)
			if rng.randf() < 0.5:
				perp = -perp

			var t_along := rng.randf()
			var base_pt := a.lerp(b, t_along)
			var road_half_w: float = float(seg["width"]) * 0.5
			var side_offset := road_half_w + rng.randf_range(road_edge_min_offset, road_edge_max_offset)
			candidate_2d = base_pt + perp * side_offset
			# Pour un prop de bord de route, petite orientation naturelle vers la route
			facing_angle = atan2(-perp.x, -perp.y) + rng.randf_range(-0.6, 0.6)

		# 1. Vérification des bordures de la carte
		if candidate_2d.x < b_margin or candidate_2d.x > map_w - b_margin or candidate_2d.y < b_margin or candidate_2d.y > map_h - b_margin:
			continue

		# 2. Ne pas spawner en plein milieu de la bande de roulement de la route !
		if path_gen.is_point_on_path(candidate_2d, -0.35):
			continue

		# 3. Éviter le point de spawn initial des joueurs (rayon 22m)
		if spawn_start_2d != Vector2.ZERO and candidate_2d.distance_squared_to(spawn_start_2d) < 484.0:
			continue

		# 4. Éviter les Encounters (villages, totems, cages PNJ), Petites Stèles et les Arènes de Boss
		if _is_inside_excluded_zones(candidate_2d, encounter_positions, encounter_exclusion_radius, arena_zones, lesser_stele_pts):
			continue

		# 5. Espacement minimal avec les autres instances de ce même prop
		var too_close := false
		for prev in placed_positions_2d:
			if candidate_2d.distance_squared_to(prev) < min_spacing_sq:
				too_close = true
				break
		if too_close:
			continue

		# 6. Vérification de collision avec les troncs d'arbres (surtout crucial pour la Racine-Catapulte !)
		var required_clearance := tree_trunk_clearance
		if placement_style == PlacementStyle.ROADSIDE_CLEAR_LAUNCH:
			required_clearance = maxf(tree_trunk_clearance, 3.2)
		if _collides_with_any_tree_trunk(candidate_2d, required_clearance, tree_grid, tree_cell_size):
			continue

		# 7. Hauteur et pente sur le Terrain3D
		var ground_y: float = terrain_data.get_height(Vector3(candidate_2d.x, 0.0, candidate_2d.y))
		if is_nan(ground_y):
			continue

		var h_px: float = terrain_data.get_height(Vector3(candidate_2d.x + 1.0, 0.0, candidate_2d.y))
		var h_pz: float = terrain_data.get_height(Vector3(candidate_2d.x, 0.0, candidate_2d.y + 1.0))
		if is_nan(h_px) or is_nan(h_pz):
			continue

		var sx := absf(h_px - ground_y)
		var sz := absf(h_pz - ground_y)
		if sx > slope_limit or sz > slope_limit:
			continue

		# Position validée ! Instanciation déterministe (Prop_0, Prop_1...)
		var inst := prop_scene.instantiate() as Node3D
		if inst == null:
			break

		inst.name = "Prop_" + str(spawned_count)
		add_child(inst)

		var final_pos := Vector3(candidate_2d.x, ground_y + ground_sink_offset, candidate_2d.y)
		var s_val := rng.randf_range(min_scale, max_scale)

		var up_vec := Vector3.UP
		if align_to_ground_normal and placement_style != PlacementStyle.ROADSIDE_CLEAR_LAUNCH:
			var raw_normal := Vector3(ground_y - h_px, 1.0, ground_y - h_pz).normalized()
			up_vec = Vector3.UP.lerp(raw_normal, ground_tilt_strength).normalized()

		var basis_rot := Basis(Vector3.UP, facing_angle)
		if up_vec.distance_squared_to(Vector3.UP) > 0.0001:
			var rot_axis := Vector3.UP.cross(up_vec)
			if rot_axis.length_squared() > 0.0001:
				var tilt_q := Quaternion(rot_axis.normalized(), Vector3.UP.angle_to(up_vec))
				basis_rot = Basis(tilt_q) * basis_rot

		inst.global_transform = Transform3D(basis_rot.scaled(Vector3.ONE * s_val), final_pos)

		placed_positions_2d.append(candidate_2d)
		spawned_count += 1

	print("[RoadForestPropSpawner] '", name, "' : ", spawned_count, "/", target_count, " instances générées (fréquence = ", snappedf(spawn_frequency, 0.01), ").")

func _is_inside_excluded_zones(pt: Vector2, encounters: Array, enc_rad: float, arenas: Array, lesser_steles: Array = []) -> bool:
	var enc_rad_sq := enc_rad * enc_rad
	for ep in encounters:
		if ep is Vector2 and pt.distance_squared_to(ep) < enc_rad_sq:
			return true
	for ls in lesser_steles:
		if ls is Vector2 and pt.distance_squared_to(ls) < 324.0:
			return true
	for az in arenas:
		if az is Dictionary and az.has("min_x"):
			var pad := 15.0
			if pt.x >= float(az["min_x"]) - pad and pt.x <= float(az["max_x"]) + pad and pt.y >= float(az["min_z"]) - pad and pt.y <= float(az["max_z"]) + pad:
				return true
	return false

func _collides_with_any_tree_trunk(pt: Vector2, clearance: float, tree_grid: Dictionary, cell_size: float) -> bool:
	if tree_grid.is_empty():
		return false
	var cx := int(floor(pt.x / cell_size))
	var cz := int(floor(pt.y / cell_size))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not tree_grid.has(key):
				continue
			for t_info in tree_grid[key]:
				var tp: Vector3 = t_info["trunk_pos"]
				var min_d: float = float(t_info["trunk_radius"]) + clearance
				var dxp := pt.x - tp.x
				var dzp := pt.y - tp.z
				if (dxp * dxp + dzp * dzp) < (min_d * min_d):
					return true
	return false

func _find_map_generator() -> Node3D:
	var p := get_parent()
	while p != null:
		if "world_seed" in p and "path_generator" in p:
			return p as Node3D
		p = p.get_parent()
	return null
