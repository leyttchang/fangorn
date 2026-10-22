class_name MarkerTreeSpawnerComponent
extends Node3D

## Composant Spawner d'Arbres par Marker3D et Lignes (MultiMeshInstance3D)
## Détecte tous les Marker3D enfants et/ou trace un mur continu d'arbres le long d'une Line2D / Path3D,
## espacé exactement de l'épaisseur du tronc pour former un mur naturel infranchissable.

const TreeSpawnEntry = preload("res://map/map_generator/tree_spawn_entry.gd")

@export_category("Variations d'Arbres")
## Scène d'arbre par défaut si aucune variation n'est spécifiée
@export var default_tree_scene: PackedScene = preload("res://objet/tree/Island_tree_hb.tscn")
## Liste simple de scènes d'arbres à glisser-déposer (tirage équiprobable entre elles)
@export var tree_scenes: Array[PackedScene] = []
## Liste avancée de variations d'arbres avec poids et multiplicateurs d'échelle (TreeSpawnEntry)
@export var tree_variations: Array[TreeSpawnEntry] = []

@export_category("Marqueurs Ponctuels (Marker3D)")
## Nœud conteneur optionnel des Marker3D. Si vide, recherche parmi les enfants de ce composant.
@export var markers_container: Node3D = null
## Masquer automatiquement les Marker3D au lancement du jeu
@export var hide_markers_in_game: bool = true

@export_category("Mur d'Arbres le long d'une Courbe")
## Nœud Path3D qui trace le mur d'arbres (courbe dessinée directement dans la vue 3D)
@export var wall_path_3d: Path3D = null
## Boucler le mur (relie automatiquement le dernier point au premier point)
@export var close_wall_loop: bool = false
## Espacement automatique calculé selon l'épaisseur exacte du tronc de chaque arbre
@export var auto_spacing_by_trunk: bool = true
## Multiplicateur d'espacement (1.0 = troncs qui se touchent bord à bord, 0.65 = espacement ~10m pour arbres géants scale 24-32)
@export_range(0.5, 3.0, 0.05) var wall_spacing_factor: float = 0.65
## Espacement manuel en mètres le long de la ligne (utilisé si auto_spacing_by_trunk est désactivé)
@export var manual_wall_spacing: float = 0.0
## Nombre de rangées d'arbres pour épaissir le mur (1 = rangée simple, 2 = double rangée en quinconce, 3 = triple)
@export_range(1, 3, 1) var wall_rows: int = 1
## Écartement entre les rangées si wall_rows > 1 (en mètres)
@export var row_spacing: float = 6.0
## Légère variation latérale aléatoire pour donner un aspect naturel sans rompre le mur (en mètres)
@export var wall_jitter: float = 0.5
## Adoucir automatiquement les angles pour former une belle courbe arrondie fluide (Chaikin smoothing)
@export var smooth_wall_angles: bool = true
## Niveau de lissage automatique (1 = adouci, 2 = courbe très fluide et naturelle, 3 = courbe parfaite)
@export_range(1, 4, 1) var smoothing_iterations: int = 2

@export_category("Aléatoire & Transformations")
## Échelle minimale globale (calée sur les arbres géants du mur de frontière)
@export var min_scale: float = 24.0
## Échelle maximale globale (calée sur les arbres géants du mur de frontière)
@export var max_scale: float = 32.0
## Prendre en compte l'échelle locale (Y) définie directement sur chaque Marker3D
@export var use_marker_scale: bool = true
## Graine aléatoire (0 = aléatoire à chaque partie, >0 = graine fixe pour répétabilité)
@export var random_seed: int = 0

@export_category("Ancrage au Sol")
## Aligner automatiquement les arbres sur la hauteur du sol sous chaque point
@export var snap_to_ground: bool = true
## Décalage vertical supplémentaire en mètres (ajustement de racine)
@export var height_offset: float = 0.0
## Rayon de sonde pour compenser les pentes (enfonce légèrement le tronc pour éviter qu'il flotte)
@export var ground_slope_compensation: bool = true

@export_category("Physique & Collisions")
## Activer les collisions physiques sur les arbres générés
@export var enable_collisions: bool = true
## Si vrai, utilise PhysicsServer3D en C++ (0 nœud dans la scène, performances maximales).
## Si faux, instancie des StaticBody3D classiques.
@export var use_physics_server: bool = true
## Collision layer personnalisé (par défaut 129 = World/Decors + Obstacles)
@export var collision_layer: int = 129
## Collision mask personnalisé
@export var collision_mask: int = 3

@export_category("Optimisation Rendu")
## Distance maximale d'affichage des arbres en mètres (au-delà, l'arbre n'est plus dessiné)
@export var visibility_range_end: float = 350.0
## Marge de transition douce de disparition
@export var visibility_range_end_margin: float = 50.0
## Activer ou désactiver les ombres sur les arbres générés (OFF par défaut comme le mur de frontière pour préserver les FPS)
@export var cast_shadows: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

@export_category("Actions & Déclenchement")
## Si vrai, génère automatiquement les arbres dans _ready().
## Si faux, attend un appel explicite à spawn_trees() (ex: par MapGenerator).
@export var auto_spawn_on_ready: bool = true

## Coche cette case dans l'inspecteur pour générer les arbres immédiatement !
@export var spawn_now: bool = false:
	set(val):
		if val:
			spawn_now = false
			spawn_trees()

## Coche cette case dans l'inspecteur pour nettoyer les arbres générés !
@export var clear_now: bool = false:
	set(val):
		if val:
			clear_now = false
			clear_spawned_trees()

## Fournisseur de hauteur (Callable(x, z) -> float), SEULE source de hauteur du sol quand snap_to_ground est actif :
## il est défini par l'ArenaGenerator (MapGenerator.get_terrain_height_at) et pose les arbres pile sur le sol, même hors de la map.
var height_provider: Callable = Callable()
var _ground_error_reported: bool = false

var _physics_body_rids: Array[RID] = []
var _spawned_instances_data: Array[Dictionary] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if auto_spawn_on_ready:
		spawn_trees()

func _exit_tree() -> void:
	_clear_physics_server_bodies()

## Déclenche la collecte des markers / lignes et le spawn complet des arbres en MultiMesh
func spawn_trees() -> void:
	clear_spawned_trees()
	
	var markers: Array[Marker3D] = _collect_markers()
	var wall_pts: Array[Vector3] = _collect_wall_points()
	
	if markers.is_empty() and wall_pts.size() < 2:
		return
	
	var active_variations = _prepare_tree_models()
	if active_variations.is_empty():
		push_warning("[MarkerTreeSpawnerComponent] Aucun modèle d'arbre valide disponible.")
		return
	
	_ground_error_reported = false
	
	var rng = RandomNumberGenerator.new()
	if random_seed > 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	
	# Structure de collecte des transforms par espèce
	var variation_transforms: Array[Array] = []
	var variation_instances: Array[Array] = []
	for i in range(active_variations.size()):
		variation_transforms.append([])
		variation_instances.append([])
	
	var total_weight: float = 0.0
	for v in active_variations:
		total_weight += v["weight"]
	
	# 1. Placement des Marker3D ponctuels
	for marker in markers:
		if not is_instance_valid(marker):
			continue
		
		if hide_markers_in_game:
			marker.visible = false
		
		var pick_idx: int = _pick_variation_index(active_variations, total_weight, rng)
		var v_data = active_variations[pick_idx]
		
		var base_scale: float = rng.randf_range(min_scale, max_scale)
		if use_marker_scale:
			base_scale *= marker.scale.y
		var final_scale: float = base_scale * v_data["scale_multiplier"]
		
		var rot_y: float = rng.randf_range(0.0, TAU)
		var marker_world_pos: Vector3 = marker.global_position
		
		_add_tree_instance(marker_world_pos, final_scale, rot_y, pick_idx, v_data, variation_transforms, variation_instances)
	
	# 2. Placement du mur d'arbres le long de la ligne
	if wall_pts.size() >= 2:
		_spawn_wall_trees(wall_pts, active_variations, total_weight, rng, variation_transforms, variation_instances)
	
	# 3. Création des MultiMeshInstance3D pour chaque espèce
	for vi in range(active_variations.size()):
		var transforms: Array = variation_transforms[vi]
		var count: int = transforms.size()
		if count == 0:
			continue
		
		var v_data = active_variations[vi]
		var mmi = MultiMeshInstance3D.new()
		mmi.name = "TreeMultiMesh_" + str(vi)
		mmi.cast_shadow = cast_shadows
		mmi.visibility_range_end = visibility_range_end
		mmi.visibility_range_end_margin = visibility_range_end_margin
		
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = v_data["mesh"]
		mm.instance_count = count
		
		for idx in range(count):
			mm.set_instance_transform(idx, transforms[idx])
		
		mmi.multimesh = mm
		if v_data["material"] != null:
			mmi.material_override = v_data["material"]
			# Enregistrement auprès du WindManager pour synchroniser le balancement
			if is_inside_tree():
				var wind_singleton = get_node_or_null("/root/Wind")
				if wind_singleton != null and v_data["material"] is ShaderMaterial:
					if wind_singleton.has_method("register_grass_material"):
						wind_singleton.register_grass_material(v_data["material"])
		
		add_child(mmi)
	
	# 4. Configuration des collisions physiques
	if enable_collisions:
		_setup_all_collisions(variation_instances, active_variations)
	
	print("[MarkerTreeSpawnerComponent] ", _spawned_instances_data.size(), " arbre(s) généré(s) au total (Markers + Mur).")

## Plante les arbres le long de la ligne à distance d'épaisseur de tronc
func _spawn_wall_trees(wall_pts: Array[Vector3], active_variations: Array[Dictionary], total_weight: float, rng: RandomNumberGenerator, variation_transforms: Array[Array], variation_instances: Array[Array]) -> void:
	var pts: Array[Vector3] = wall_pts.duplicate()
	var is_loop: bool = close_wall_loop or pts[0].distance_squared_to(pts[-1]) < 4.0
	
	# Lissage automatique des angles (Chaikin's Corner Cutting algorithm)
	if smooth_wall_angles and pts.size() >= 3:
		pts = _smooth_polyline(pts, is_loop, smoothing_iterations)
		
	if is_loop and pts[0].distance_squared_to(pts[-1]) > 0.01:
		pts.append(pts[0])
		
	var seg_starts: Array[Vector3] = []
	var seg_dirs: Array[Vector3] = []
	var seg_normals: Array[Vector3] = []
	var seg_lengths: Array[float] = []
	var total_length: float = 0.0
	
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var diff = Vector3(p2.x - p1.x, 0.0, p2.z - p1.z)
		var l = diff.length()
		if l < 0.05:
			continue
		var dir = diff / l
		var norm = Vector3(-dir.z, 0.0, dir.x)
		
		seg_starts.append(p1)
		seg_dirs.append(dir)
		seg_normals.append(norm)
		seg_lengths.append(l)
		total_length += l
		
	if seg_lengths.is_empty():
		return
		
	var seg_idx: int = 0
	var current_seg_dist: float = 0.0
	var is_first_tree: bool = true
	
	while seg_idx < seg_lengths.size():
		var pick_idx: int = _pick_variation_index(active_variations, total_weight, rng)
		var v_data = active_variations[pick_idx]
		
		var final_scale: float = rng.randf_range(min_scale, max_scale) * v_data["scale_multiplier"]
		var trunk_radius: float = v_data["trunk_radius"] * final_scale
		var trunk_thickness: float = maxf(0.2, trunk_radius * 2.0)
		
		var step_dist: float
		if auto_spacing_by_trunk:
			step_dist = maxf(0.25, trunk_thickness * wall_spacing_factor)
		else:
			step_dist = maxf(0.25, manual_wall_spacing if manual_wall_spacing > 0.0 else trunk_thickness)
			
		if is_first_tree:
			is_first_tree = false
			current_seg_dist = minf(step_dist * 0.5, seg_lengths[seg_idx] * 0.5)
			
		var seg_p1 = seg_starts[seg_idx]
		var seg_dir = seg_dirs[seg_idx]
		var seg_norm = seg_normals[seg_idx]
		var base_pos = seg_p1 + seg_dir * current_seg_dist
		
		# Création des rangées
		for row in range(wall_rows):
			var row_offset: float = 0.0
			if wall_rows > 1:
				row_offset = (float(row) - float(wall_rows - 1) * 0.5) * row_spacing
			
			var quinconce_advance: float = 0.0
			if row % 2 == 1:
				quinconce_advance = step_dist * 0.5
				
			var pos_jitter = rng.randf_range(-wall_jitter, wall_jitter) if wall_jitter > 0.0 else 0.0
			var tree_xz = base_pos + seg_dir * quinconce_advance + seg_norm * (row_offset + pos_jitter)
			var rot_y: float = rng.randf_range(0.0, TAU)
			
			_add_tree_instance(tree_xz, final_scale, rot_y, pick_idx, v_data, variation_transforms, variation_instances)
		
		current_seg_dist += step_dist
		while seg_idx < seg_lengths.size() and current_seg_dist > seg_lengths[seg_idx]:
			current_seg_dist -= seg_lengths[seg_idx]
			seg_idx += 1

## Adoucit une polyligne en arrondissant tous les angles (Algorithme Chaikin)
func _smooth_polyline(input_pts: Array[Vector3], is_loop: bool, iterations: int) -> Array[Vector3]:
	var current: Array[Vector3] = input_pts.duplicate()
	for iter in range(iterations):
		var next_pts: Array[Vector3] = []
		var count: int = current.size()
		if is_loop:
			for i in range(count):
				var p0 = current[i]
				var p1 = current[(i + 1) % count]
				var q = p0.lerp(p1, 0.25)
				var r = p0.lerp(p1, 0.75)
				next_pts.append(q)
				next_pts.append(r)
		else:
			next_pts.append(current[0])
			for i in range(count - 1):
				var p0 = current[i]
				var p1 = current[i + 1]
				var q = p0.lerp(p1, 0.25)
				var r = p0.lerp(p1, 0.75)
				next_pts.append(q)
				next_pts.append(r)
			next_pts.append(current[-1])
		current = next_pts
	return current

## Calcule l'alignement sol et enregistre une instance d'arbre
func _add_tree_instance(pos_xz: Vector3, final_scale: float, rot_y: float, pick_idx: int, v_data: Dictionary, variation_transforms: Array[Array], variation_instances: Array[Array]) -> void:
	var ground_y: float = pos_xz.y
	var trunk_radius: float = v_data["trunk_radius"] * final_scale
	
	if snap_to_ground:
		var detected_y: float = _get_ground_height(pos_xz.x, pos_xz.z)
		if is_nan(detected_y):
			return # sol inconnu : pas d'arbre plutôt qu'un arbre à une hauteur arbitraire
		ground_y = detected_y
		if ground_slope_compensation and trunk_radius > 0.0:
			var tr = trunk_radius
			var min_h = ground_y
			for probe in [Vector2(0.0, tr), Vector2(0.0, -tr), Vector2(tr, 0.0), Vector2(-tr, 0.0)]:
				var h_probe: float = _get_ground_height(pos_xz.x + probe.x, pos_xz.z + probe.y)
				if not is_nan(h_probe):
					min_h = minf(min_h, h_probe)
			ground_y = min_h - 0.15
	
	var final_y: float = ground_y - (v_data["ground_offset"] * final_scale) + height_offset
	var tree_world_pos: Vector3 = Vector3(pos_xz.x, final_y, pos_xz.z)
	
	var rot_basis: Basis = Basis(Vector3.UP, rot_y)
	var visual_basis: Basis = (rot_basis * v_data["mesh_basis"]).scaled(Vector3.ONE * final_scale)
	var visual_pos: Vector3 = tree_world_pos + rot_basis * (v_data["mesh_offset"] * final_scale)
	
	var local_t = global_transform.affine_inverse() * Transform3D(visual_basis, visual_pos)
	variation_transforms[pick_idx].append(local_t)
	
	var inst_info = {
		"world_pos": tree_world_pos,
		"rot_y": rot_y,
		"scale": final_scale,
		"v_idx": pick_idx
	}
	variation_instances[pick_idx].append(inst_info)
	_spawned_instances_data.append(inst_info)

func _pick_variation_index(active_variations: Array[Dictionary], total_weight: float, rng: RandomNumberGenerator) -> int:
	if active_variations.size() <= 1:
		return 0
	var roll = rng.randf_range(0.0, total_weight)
	var accum = 0.0
	for vi in range(active_variations.size()):
		accum += active_variations[vi]["weight"]
		if roll <= accum:
			return vi
	return 0

## Nettoie les arbres et collisions générés
func clear_spawned_trees() -> void:
	_clear_physics_server_bodies()
	_spawned_instances_data.clear()
	
	var colliders_node = get_node_or_null("TreeColliders")
	if colliders_node != null:
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

func _collect_markers() -> Array[Marker3D]:
	var results: Array[Marker3D] = []
	var root_node = markers_container if markers_container != null else self
	for child in root_node.find_children("*", "Marker3D", true, false):
		if child is Marker3D:
			results.append(child)
	return results

func _collect_wall_points() -> Array[Vector3]:
	var points_3d: Array[Vector3] = []
	if wall_path_3d == null or wall_path_3d.curve == null:
		return points_3d
	for pt in wall_path_3d.curve.get_baked_points():
		points_3d.append(wall_path_3d.to_global(pt))
	return points_3d

func _prepare_tree_models() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	if not tree_variations.is_empty():
		for entry in tree_variations:
			if entry != null and entry.tree_scene != null and entry.weight > 0.0:
				var data = _extract_model_data(entry.tree_scene)
				if data["mesh"] != null:
					data["name"] = entry.name
					data["weight"] = entry.weight
					data["scale_multiplier"] = entry.scale_multiplier
					result.append(data)
	
	if result.is_empty() and not tree_scenes.is_empty():
		for scn in tree_scenes:
			if scn != null:
				var data = _extract_model_data(scn)
				if data["mesh"] != null:
					data["name"] = scn.resource_path.get_file().get_basename()
					data["weight"] = 1.0
					data["scale_multiplier"] = 1.0
					result.append(data)
	
	if result.is_empty() and default_tree_scene != null:
		var data = _extract_model_data(default_tree_scene)
		if data["mesh"] != null:
			data["name"] = "DefaultTree"
			data["weight"] = 1.0
			data["scale_multiplier"] = 1.0
			result.append(data)
			
	return result

func _extract_model_data(scene: PackedScene) -> Dictionary:
	var result = {
		"mesh": null,
		"mesh_basis": Basis(),
		"mesh_offset": Vector3.ZERO,
		"material": null,
		"shape": null,
		"shape_offset": Vector3.ZERO,
		"trunk_radius": 0.3,
		"ground_offset": 0.0
	}
	
	var inst = scene.instantiate()
	for n in inst.find_children("*", "", true, false):
		if n is MeshInstance3D and result.mesh == null:
			result.mesh = n.mesh
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
		elif n is CollisionShape3D and result.shape == null:
			result.shape = n.shape
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.shape_offset = rel_t.origin
			var s: float = rel_t.basis.get_scale().x
			if n.shape is CylinderShape3D:
				result.trunk_radius = (n.shape as CylinderShape3D).radius * s
			elif n.shape is CapsuleShape3D:
				result.trunk_radius = (n.shape as CapsuleShape3D).radius * s
			elif n.shape is BoxShape3D:
				var sz = (n.shape as BoxShape3D).size
				result.trunk_radius = maxf(sz.x, sz.z) * 0.5 * s
		elif n is Marker3D and result.ground_offset == 0.0:
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.ground_offset = rel_t.origin.y
			
	inst.queue_free()
	return result

## Hauteur du sol en (px, pz) fournie par `height_provider` (seule source). NAN + erreur (une seule fois) si le fournisseur
## est absent/invalide ou ne connaît pas ce point : l'appelant ne plante alors pas l'arbre.
func _get_ground_height(px: float, pz: float) -> float:
	if not height_provider.is_valid():
		if not _ground_error_reported:
			_ground_error_reported = true
			push_error("[MarkerTreeSpawnerComponent] height_provider non défini : impossible de poser les arbres au sol (le composant doit être piloté par l'ArenaGenerator).")
		return NAN
	var h: float = height_provider.call(px, pz)
	if is_nan(h) and not _ground_error_reported:
		_ground_error_reported = true
		push_error("[MarkerTreeSpawnerComponent] hauteur de sol introuvable en (%.1f, %.1f)." % [px, pz])
	return h

func _setup_all_collisions(variation_instances: Array[Array], active_variations: Array[Dictionary]) -> void:
	for vi in range(active_variations.size()):
		var v_data = active_variations[vi]
		var instances = variation_instances[vi]
		if instances.is_empty() or v_data["shape"] == null:
			continue
			
		if use_physics_server:
			var w3d = get_world_3d()
			if w3d == null:
				continue
			var space: RID = w3d.space
			var shape_rid: RID = v_data["shape"].get_rid()
			
			for inst in instances:
				var s: float = inst["scale"]
				var rot_y: float = inst["rot_y"]
				var pos: Vector3 = inst["world_pos"]
				
				var body: RID = PhysicsServer3D.body_create()
				if not body.is_valid():
					break
				
				PhysicsServer3D.body_set_space(body, space)
				PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
				PhysicsServer3D.body_set_collision_layer(body, collision_layer)
				PhysicsServer3D.body_set_collision_mask(body, collision_mask)
				
				var local_shape_t = Transform3D(Basis().scaled(Vector3.ONE * s), v_data["shape_offset"] * s)
				PhysicsServer3D.body_add_shape(body, shape_rid, local_shape_t)
				
				var body_t = Transform3D(Basis(Vector3.UP, rot_y), pos)
				PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, body_t)
				_physics_body_rids.append(body)
		else:
			var colliders_node = get_node_or_null("TreeColliders")
			if colliders_node == null:
				colliders_node = Node3D.new()
				colliders_node.name = "TreeColliders"
				add_child(colliders_node)
				
			for inst in instances:
				var s: float = inst["scale"]
				var rot_y: float = inst["rot_y"]
				var pos: Vector3 = inst["world_pos"]
				
				var body = StaticBody3D.new()
				body.collision_layer = collision_layer
				body.collision_mask = collision_mask
				body.global_transform = Transform3D(Basis(Vector3.UP, rot_y), pos)
				
				var col = CollisionShape3D.new()
				col.shape = v_data["shape"]
				col.scale = Vector3.ONE * s
				col.position = v_data["shape_offset"] * s
				body.add_child(col)
				colliders_node.add_child(body)

func _clear_physics_server_bodies() -> void:
	for body in _physics_body_rids:
		if body.is_valid():
			PhysicsServer3D.free_rid(body)
	_physics_body_rids.clear()
