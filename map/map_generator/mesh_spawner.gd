@tool
class_name MeshSpawner
extends Node3D

const TreeSpawnEntry = preload("res://map/map_generator/tree_spawn_entry.gd")

@export_category("Références")
@export var map_generator: Node3D
@export var terrain: Terrain3D
@export var path_generator: PathGenerator

@export_category("Variations d'Arbres")
## Liste des différentes espèces/variations d'arbres avec leur poids d'apparition.
## Tu peux y glisser des fichiers .tres ou créer de nouveaux TreeSpawnEntry directement ici !
@export var tree_variations: Array[TreeSpawnEntry] = []
## Scène d'arbre de repli (utilisée si tree_variations est vide)
@export var tree_scene: PackedScene = preload("res://objet/tree/Island_tree_hb.tscn")

@export_category("Bruit de Forêt (Densité)")
## FastNoiseLite pour gérer la répartition des massifs de forêts et des clairières
@export var forest_noise: FastNoiseLite
## Seuil pour faire pousser un arbre (-1.0 à 1.0). Plus c'est haut, plus les forêts sont denses et séparées par des clairières.
@export_range(-1.0, 1.0, 0.05) var forest_threshold: float = 0.15

@export_category("Seed / Graine")
## Graine aléatoire synchronisée avec le Map_generator (même seed = exactement les mêmes arbres et forêts).
@export var spawn_seed: int = 12345

@export_category("Distribution & Placement")

## Espacement moyen de la grille de spawn (en mètres). Avec des arbres scale ~10 (40-50m de large), 25.0 à 30.0m donne une forêt dense et naturelle.
@export var grid_spacing: float = 28.0
## Décalage aléatoire pour un placement organique (en mètres)
@export var jitter: float = 8.0
## Marge de sécurité par rapport au bord de la route (en mètres). Avec des arbres scale 10, 10.0 à 15.0m évite tout débordement de branches sur la route.
@export var road_margin: float = 12.0
## Nombre maximum d'arbres à générer sur toute la carte (sécurité anti-freeze)
@export var max_trees: int = 10000
## Échelle minimale de l'arbre
@export var min_scale: float = 8.0
## Échelle maximale de l'arbre
@export var max_scale: float = 12.0
## Pente maximale tolérée (en degrés). Évite que des arbres poussent sur des falaises à pic.
@export_range(10.0, 85.0, 1.0) var max_slope_degrees: float = 40.0

@export_category("Alignement Sol & Pentes")
## Décalage vertical manuel (en mètres, avant scale). S'ajoute au Marker3D de la scène s'il existe.
@export var extra_height_offset: float = 0.0
## Si activé, sonde le sol autour du tronc pour ancrer l'arbre sur le point le plus bas (évite que le tronc flotte sur les collines).
@export var ground_slope_compensation: bool = true
## Enfoncement de sécurité des racines dans le sol (en mètres).
@export var root_sink_depth: float = 0.2

@export_category("Physique & Collisions")
## Recommandé VRAI : utilise PhysicsServer3D en C++ direct (0 Node dans la scène, 100x plus rapide, 0 freeze).
@export var use_physics_server: bool = true

@export_category("Actions")
## Coche cette case dans l'inspecteur pour générer les arbres immédiatement !
@export var spawn_trees_now: bool = false:
	set(value):
		spawn_trees_now = false
		if Engine.is_editor_hint():
			call_deferred("generate_trees")

## Coche cette case dans l'inspecteur pour supprimer tous les arbres !
@export var clear_trees_now: bool = false:
	set(value):
		clear_trees_now = false
		clear_trees()

# RIDs internes si use_physics_server est actif
var _physics_body_rids: Array[RID] = []
var _is_generating: bool = false
var _cached_tree_shape: Shape3D = null
var _cached_tree_mesh: Mesh = null
var _cached_tree_material: Material = null

func _ready() -> void:
	_ensure_default_noise()
	_connect_to_map_generator()
	
	if not Engine.is_editor_hint():
		if map_generator and map_generator.has_signal("terrain_ready"):
			if not map_generator.terrain_ready.is_connected(generate_trees):
				map_generator.terrain_ready.connect(generate_trees)

func _exit_tree() -> void:
	_clear_physics_server_bodies()

func _safe_await_frame() -> void:
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame

func _ensure_default_noise() -> void:
	if forest_noise == null:
		forest_noise = FastNoiseLite.new()
		forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		forest_noise.frequency = 0.005
		forest_noise.fractal_octaves = 3

func _connect_to_map_generator() -> void:
	if map_generator == null and get_parent() != null and get_parent().name == "Map_generator":
		map_generator = get_parent()
	if terrain == null and map_generator and "terrain" in map_generator:
		terrain = map_generator.terrain
	if path_generator == null and map_generator and "path_generator" in map_generator:
		path_generator = map_generator.path_generator

## Nettoie tous les arbres (MultiMesh et collisions)
func clear_trees() -> void:
	_clear_physics_server_bodies()
	
	var colliders_node = get_node_or_null("TreeColliders")
	if colliders_node:
		colliders_node.queue_free()
		remove_child(colliders_node)
	
	var to_remove = []
	for child in get_children():
		if child is MultiMeshInstance3D:
			to_remove.append(child)
	for child in to_remove:
		child.multimesh = null
		child.queue_free()
		remove_child(child)

## Génère les arbres de manière asynchrone et ultra-optimisée
func generate_trees() -> void:
	if _is_generating:
		return
	_is_generating = true
	
	_connect_to_map_generator()
	if map_generator != null and "world_seed" in map_generator:
		spawn_seed = map_generator.world_seed
	elif map_generator != null and "map_seed" in map_generator:
		spawn_seed = map_generator.map_seed
		
	_ensure_default_noise()
	forest_noise.seed = spawn_seed + 101
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = spawn_seed + 202
	
	if terrain == null:
		push_error("MeshSpawner: Aucun Terrain3D assigné !")
		_is_generating = false
		return

		
	var terrain_data = null
	if "data" in terrain: terrain_data = terrain.data
	elif "storage" in terrain: terrain_data = terrain.storage
	
	if terrain_data == null:
		push_error("MeshSpawner: Impossible d'accéder aux données de Terrain3D !")
		_is_generating = false
		return
		
	print("Début du spawn des arbres...")
	clear_trees()
	
	# Pause pour laisser respirer le moteur après le nettoyage
	await _safe_await_frame()
	
	# 1. Préparation et extraction des modèles d'arbres actifs
	var active_variations: Array[Dictionary] = []
	
	if tree_variations != null and not tree_variations.is_empty():
		for entry in tree_variations:
			if entry != null and entry.tree_scene != null and entry.weight > 0.0:
				var data = _extract_tree_model_data(entry.tree_scene)
				if data.mesh != null:
					data["name"] = entry.name
					data["weight"] = entry.weight
					data["scale_multiplier"] = entry.scale_multiplier
					active_variations.append(data)
				else:
					push_warning("MeshSpawner: Pas de MeshInstance3D valide dans '" + entry.name + "'")
	
	# Si aucune variation valide dans tree_variations, on utilise tree_scene en repli
	if active_variations.is_empty():
		if tree_scene != null:
			var data = _extract_tree_model_data(tree_scene)
			if data.mesh != null:
				data["name"] = "DefaultTree"
				data["weight"] = 1.0
				data["scale_multiplier"] = 1.0
				active_variations.append(data)
				
	if active_variations.is_empty():
		push_error("MeshSpawner: Aucune variation d'arbre valide à générer !")
		_is_generating = false
		return
		
	var total_weight: float = 0.0
	for v in active_variations:
		total_weight += v["weight"]
		
	print("MeshSpawner: ", active_variations.size(), " espèce(s) configurée(s) (Poids total: ", total_weight, ").")
		
	# 2. Dimensions de la carte
	var map_w: float = 2048.0
	var map_h: float = 2048.0
	if map_generator != null:
		if "map_width_chunks" in map_generator and "region_size" in map_generator:
			map_w = float(map_generator.map_width_chunks * map_generator.region_size)
		if "map_height_chunks" in map_generator and "region_size" in map_generator:
			map_h = float(map_generator.map_height_chunks * map_generator.region_size)
			
	# 3. Grille spatiale pour les routes (accélère le test de route par 1000x !)
	var road_cell_size: float = 256.0
	var road_spatial_grid: Dictionary = _build_road_spatial_grid(road_cell_size, road_margin)
	
	var slope_threshold: float = tan(deg_to_rad(clampf(max_slope_degrees, 5.0, 85.0)))
	var spacing: float = maxf(3.0, grid_spacing)
	var max_jitter: float = clampf(jitter, 0.0, spacing * 0.45)
	var time_start: int = Time.get_ticks_msec()
	
	# 4. Parcours de la grille avec filtre rapide par bruit
	var variation_transforms: Array[Array] = []
	var variation_instances: Array[Array] = []
	for i in range(active_variations.size()):
		var t_arr: Array[Transform3D] = []
		var i_arr: Array[Dictionary] = []
		variation_transforms.append(t_arr)
		variation_instances.append(i_arr)
		
	var total_spawned: int = 0
	var margin: float = spacing
	var row_counter: int = 0
	
	var z: float = margin
	while z < map_h - margin and total_spawned < max_trees:
		row_counter += 1
		# Laisse le moteur respirer toutes les 32 rangées pour éviter tout freeze/crash
		if row_counter % 32 == 0:
			await _safe_await_frame()
			
		var x: float = margin
		while x < map_w - margin and total_spawned < max_trees:
			var px: float = x + rng.randf_range(-max_jitter, max_jitter)
			var pz: float = z + rng.randf_range(-max_jitter, max_jitter)
			
			# FILTRE 1 (Le plus rapide) : Bruit de forêt
			# Rejette 70-80% des points instantanément en 1 nanoseconde !
			if forest_noise.get_noise_2d(px, pz) < forest_threshold:
				x += spacing
				continue
				
			# FILTRE 2 : Évitement de la route via la grille spatiale ultra-rapide
			if _is_near_road_spatial(px, pz, road_margin, road_spatial_grid, road_cell_size):
				x += spacing
				continue
				
			# FILTRE 3 : Hauteur au sol sur le terrain
			var pos_3d = Vector3(px, 0.0, pz)
			var ground_y: float = terrain_data.get_height(pos_3d)
			if is_nan(ground_y):
				x += spacing
				continue
				
			# FILTRE 4 : Vérification de la pente
			var test_dist: float = 1.0
			var h_east: float = terrain_data.get_height(Vector3(px + test_dist, 0.0, pz))
			var h_south: float = terrain_data.get_height(Vector3(px, 0.0, pz + test_dist))
			if not is_nan(h_east) and not is_nan(h_south):
				var slope_x = absf(h_east - ground_y) / test_dist
				var slope_z = absf(h_south - ground_y) / test_dist
				if slope_x > slope_threshold or slope_z > slope_threshold:
					x += spacing
					continue
					
			# Position acceptée ! Tirage au sort de la variante selon les poids
			var pick_idx: int = 0
			if active_variations.size() > 1:
				var roll: float = rng.randf_range(0.0, total_weight)
				var accum: float = 0.0
				for vi in range(active_variations.size()):
					accum += active_variations[vi]["weight"]
					if roll <= accum:
						pick_idx = vi
						break
			var v_data = active_variations[pick_idx]
			
			var s: float = rng.randf_range(min_scale, max_scale) * v_data["scale_multiplier"]
			var rot_y: float = rng.randf_range(0.0, TAU)

			
			# Calcul de la hauteur au sol adaptée aux pentes (évite que le tronc flotte en aval sur les collines)
			var effective_ground_y: float = ground_y
			if ground_slope_compensation:
				var trunk_r: float = v_data["trunk_radius"] * s
				var h_n: float = terrain_data.get_height(Vector3(px, 0.0, pz + trunk_r))
				var h_s: float = terrain_data.get_height(Vector3(px, 0.0, pz - trunk_r))
				var h_e: float = terrain_data.get_height(Vector3(px + trunk_r, 0.0, pz))
				var h_w: float = terrain_data.get_height(Vector3(px - trunk_r, 0.0, pz))
				var min_ground: float = ground_y
				if not is_nan(h_n): min_ground = minf(min_ground, h_n)
				if not is_nan(h_s): min_ground = minf(min_ground, h_s)
				if not is_nan(h_e): min_ground = minf(min_ground, h_e)
				if not is_nan(h_w): min_ground = minf(min_ground, h_w)
				effective_ground_y = min_ground - root_sink_depth
			else:
				effective_ground_y = ground_y - root_sink_depth
				
			# Hauteur finale en appliquant le Marker3D de cette espèce et l'échelle
			var final_y: float = effective_ground_y - ((v_data["ground_offset"] + extra_height_offset) * s)
			var tree_pos: Vector3 = Vector3(px, final_y, pz)
			
			# MultiMesh transform : redresse l'arbre (en appliquant l'orientation du modèle DAE),
			# applique la rotation aléatoire autour de l'axe Y et la mise à l'échelle
			var rot_basis: Basis = Basis(Vector3.UP, rot_y)
			var orient_basis: Basis = rot_basis * v_data["mesh_basis"]
			var visual_basis: Basis = orient_basis.scaled(Vector3.ONE * s)
			var visual_pos: Vector3 = tree_pos + rot_basis * (v_data["mesh_offset"] * s)
			
			variation_transforms[pick_idx].append(Transform3D(visual_basis, visual_pos))
			variation_instances[pick_idx].append({
				"pos": tree_pos,
				"rot_y": rot_y,
				"scale": s
			})
			total_spawned += 1
			
			x += spacing
		z += spacing
		
	print("Arbres placés : ", total_spawned, " instances calculées en ", (Time.get_ticks_msec() - time_start), " ms.")
	
	if total_spawned == 0:
		print("Aucun arbre n'a rempli les conditions.")
		_is_generating = false
		return
		
	await _safe_await_frame()
	
	# 5. Construction des MultiMeshInstance3D pour chaque espèce
	for vi in range(active_variations.size()):
		var v_data = active_variations[vi]
		var transforms: Array = variation_transforms[vi]
		var count: int = transforms.size()
		if count == 0:
			continue
			
		var clean_name: String = v_data["name"].replace(" ", "_")
		var mmi_name: String = "MultiMesh_" + str(vi) + "_" + clean_name
		var mmi = get_node_or_null(mmi_name) as MultiMeshInstance3D
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = mmi_name
			add_child(mmi)
				
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = v_data["mesh"]
		mm.instance_count = count
		
		for i in range(count):
			mm.set_instance_transform(i, transforms[i])
			
		mmi.multimesh = mm
		if v_data["material"] != null:
			mmi.material_override = v_data["material"]
			
		print("  -> ", v_data["name"], " : ", count, " arbres créés.")
		
	await _safe_await_frame()
	
	# 6. Création des collisions pour chaque espèce
	for vi in range(active_variations.size()):
		var v_data = active_variations[vi]
		var instances: Array = variation_instances[vi]
		if not instances.is_empty() and v_data["shape"] != null:
			_setup_collisions(instances, v_data)
		
	print("Génération des arbres terminée !")
	_is_generating = false


## Construit une grille spatiale des routes pour tester uniquement les segments proches
func _build_road_spatial_grid(cell_size: float, margin: float) -> Dictionary:
	var grid: Dictionary = {}
	if path_generator == null or path_generator.segments.is_empty():
		return grid
		
	for seg in path_generator.segments:
		var safe: float = seg.width + margin
		var min_cx: int = int(floor((seg.min_x - safe) / cell_size))
		var max_cx: int = int(floor((seg.max_x + safe) / cell_size))
		var min_cz: int = int(floor((seg.min_y - safe) / cell_size))
		var max_cz: int = int(floor((seg.max_y + safe) / cell_size))
		
		for cz in range(min_cz, max_cz + 1):
			for cx in range(min_cx, max_cx + 1):
				var key = Vector2i(cx, cz)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(seg)
				
	return grid

## Test ultra-rapide d'évitement de route avec la grille spatiale
func _is_near_road_spatial(px: float, pz: float, margin: float, grid: Dictionary, cell_size: float) -> bool:
	if grid.is_empty():
		return false
		
	var key = Vector2i(int(floor(px / cell_size)), int(floor(pz / cell_size)))
	var cell_segments = grid.get(key, null)
	if cell_segments == null:
		return false
		
	for seg in cell_segments:
		var safe_dist: float = seg.width + margin
		if px < seg.min_x - safe_dist or px > seg.max_x + safe_dist or pz < seg.min_y - safe_dist or pz > seg.max_y + safe_dist:
			continue
			
		var ax: float = seg.start.x; var ay: float = seg.start.y
		var bx: float = seg.end.x;   var by: float = seg.end.y
		var dx: float = bx - ax;     var dy: float = by - ay
		var l2: float = dx * dx + dy * dy
		
		var dist_sq: float
		if l2 < 0.0001:
			var ex: float = px - ax; var ey: float = pz - ay
			dist_sq = ex * ex + ey * ey
		else:
			var t: float = clampf(((px - ax) * dx + (pz - ay) * dy) / l2, 0.0, 1.0)
			var proj_x: float = ax + t * dx
			var proj_y: float = ay + t * dy
			var ex: float = px - proj_x; var ey: float = pz - proj_y
			dist_sq = ex * ex + ey * ey
			
		if dist_sq < safe_dist * safe_dist:
			return true
			
	return false

## Configure les collisions (PhysicsServer3D C++ direct ou StaticBody3D)
func _setup_collisions(instances: Array[Dictionary], tree_data: Dictionary) -> void:
	if tree_data.shape == null:
		return
		
	if use_physics_server:
		# Option 2 : PhysicsServer3D en C++ direct (Ultra-rapide, 0 Node dans la scène !)
		var space: RID = get_world_3d().space
		var shape_rid: RID = tree_data.shape.get_rid()
		
		for inst in instances:
			var s: float = inst["scale"]
			var rot_y: float = inst["rot_y"]
			var pos: Vector3 = inst["pos"]
			
			var body: RID = PhysicsServer3D.body_create()
			if not body.is_valid():
				push_warning("MeshSpawner: Limite de corps physiques atteinte.")
				break
				
			PhysicsServer3D.body_set_space(body, space)
			PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer(body, tree_data.collision_layer)
			PhysicsServer3D.body_set_collision_mask(body, tree_data.collision_mask)
			
			# La hitbox cylindre est agrandie selon l'échelle de l'arbre
			var local_shape_t = Transform3D(Basis().scaled(Vector3.ONE * s), tree_data.shape_offset * s)
			PhysicsServer3D.body_add_shape(body, shape_rid, local_shape_t)
			
			# Le corps physique est orienté selon la rotation Y de l'arbre et placé au sol
			var body_t = Transform3D(Basis(Vector3.UP, rot_y), pos)
			PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, body_t)
			_physics_body_rids.append(body)
	else:
		# Option 1 : Conteneur de StaticBody3D
		var colliders_node = get_node_or_null("TreeColliders")
		if colliders_node == null:
			colliders_node = Node3D.new()
			colliders_node.name = "TreeColliders"
			add_child(colliders_node)
			if Engine.is_editor_hint():
				colliders_node.owner = get_tree().edited_scene_root
				
		for inst in instances:
			var s: float = inst["scale"]
			var rot_y: float = inst["rot_y"]
			var pos: Vector3 = inst["pos"]
			
			var body = StaticBody3D.new()
			body.collision_layer = tree_data.collision_layer
			body.collision_mask = tree_data.collision_mask
			body.transform = Transform3D(Basis(Vector3.UP, rot_y), pos)
			
			var col = CollisionShape3D.new()
			col.shape = tree_data.shape
			col.scale = Vector3.ONE * s
			col.position = tree_data.shape_offset * s
			body.add_child(col)
			colliders_node.add_child(body)

func _clear_physics_server_bodies() -> void:
	for body in _physics_body_rids:
		if body.is_valid():
			PhysicsServer3D.free_rid(body)
	_physics_body_rids.clear()

## Extrait le Mesh, Material et Shape depuis tree_scene en tenant compte des offsets/rotations relatifs
func _extract_tree_model_data(scene: PackedScene) -> Dictionary:
	var result = {
		"mesh": null,
		"mesh_basis": Basis(),
		"mesh_offset": Vector3.ZERO,
		"material": null,
		"shape": null,
		"shape_offset": Vector3.ZERO,
		"collision_layer": 129,
		"collision_mask": 3,
		"ground_offset": 0.0,
		"trunk_radius": 0.3
	}
	
	var inst = scene.instantiate()
	for n in inst.find_children("*", "", true, false):
		if n is MeshInstance3D and result.mesh == null:
			result.mesh = n.mesh
			# Récupère l'orientation et l'offset complets du mesh par rapport à la racine du modèle
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.mesh_basis = rel_t.basis
			result.mesh_offset = rel_t.origin
			
			result.material = n.get_surface_override_material(0)
			if result.material == null and result.mesh.get_surface_count() > 0:
				result.material = result.mesh.surface_get_material(0)
		elif n is StaticBody3D:
			result.collision_layer = n.collision_layer
			result.collision_mask = n.collision_mask
		elif n is CollisionShape3D and result.shape == null:
			result.shape = n.shape
			if n.shape is CylinderShape3D:
				result.trunk_radius = (n.shape as CylinderShape3D).radius
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.shape_offset = rel_t.origin
		elif n is Marker3D:
			# Marker3D dans la scène : indique exactement où le sol doit couper le tronc !
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.ground_offset = rel_t.origin.y
			print("MeshSpawner: Marker3D détecté ('", n.name, "') à Y = ", result.ground_offset)
			
	inst.queue_free()
	return result
