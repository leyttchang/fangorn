@tool
class_name BorderTreeWall
extends Node3D

signal wall_ready

@export_category("Références")
@export var map_generator: Node3D
@export var terrain: Terrain3D
@export var path_generator: PathGenerator

@export_category("Configuration du Mur d'Arbres")
## Espacement entre chaque arbre le long du mur (en mètres). Réglable à la main !
@export_range(4.0, 30.0, 0.5) var tree_spacing: float = 10.0

## Échelle minimale des arbres du mur (de grands arbres pour former un mur)
@export var min_scale: float = 24.0

## Échelle maximale des arbres du mur
@export var max_scale: float = 32.0

## Nombre de rangées d'arbres le long du mur (1 = ligne simple dense, 2 = quinconce)
@export_range(1, 3, 1) var wall_rows: int = 1

## Écartement entre les rangées si wall_rows > 1 (en mètres)
@export var row_spacing: float = 6.0

## Largeur de l'ouverture laissée libre en face de chaque fin de chemin (en mètres)
@export var road_opening_width: float = 32.0

## Légère variation aléatoire de position pour un rendu organique mais aligné (en mètres)
@export var jitter: float = 1.0

## Scène d'arbre utilisée pour le mur
@export var tree_scene: PackedScene = preload("res://objet/tree/Island_tree_hb.tscn")

@export_category("Physique & Collisions")
## Utilise PhysicsServer3D en C++ direct (performances maximales, 0 freeze)
@export var use_physics_server: bool = true

@export_category("Actions")
## Coche cette case pour générer le mur immédiatement
@export var generate_wall_now: bool = false:
	set(val):
		generate_wall_now = false
		if Engine.is_editor_hint():
			call_deferred("generate_wall")

## Coche cette case pour nettoyer le mur
@export var clear_wall_now: bool = false:
	set(val):
		clear_wall_now = false
		clear_wall()

var _physics_body_rids: Array[RID] = []
var _is_generating: bool = false

func _ready() -> void:
	_connect_references()

func _exit_tree() -> void:
	_clear_physics_server_bodies()

func _connect_references() -> void:
	if map_generator == null and get_parent() != null and get_parent().name == "Map_generator":
		map_generator = get_parent()
	if terrain == null and map_generator != null:
		terrain = map_generator.find_child("Terrain3D", true, false)
	if path_generator == null and map_generator != null:
		path_generator = map_generator.find_child("path_generator", true, false)

func clear_wall() -> void:
	print("BorderTreeWall: Nettoyage du mur d'arbres...")
	var to_remove: Array[Node] = []
	for child in get_children():
		if child is MultiMeshInstance3D or child.name == "WallColliders":
			to_remove.append(child)
	for n in to_remove:
		n.queue_free()
	_clear_physics_server_bodies()
	print("BorderTreeWall: Mur nettoyé !")

func _clear_physics_server_bodies() -> void:
	for body in _physics_body_rids:
		if body.is_valid():
			PhysicsServer3D.free_rid(body)
	_physics_body_rids.clear()

## Génère le mur d'arbres continu le long de la marge de la carte
func generate_wall() -> void:
	if _is_generating:
		return
	_is_generating = true
	
	_connect_references()
	if map_generator == null:
		push_error("BorderTreeWall: Aucun MapGenerator assigné !")
		_is_generating = false
		return
		
	if tree_scene == null:
		push_error("BorderTreeWall: Aucune tree_scene assignée !")
		_is_generating = false
		return
		
	var time_start = Time.get_ticks_msec()
	print("BorderTreeWall: Début de la génération du mur d'arbres...")
	clear_wall()
	
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		
	var tree_data = _extract_tree_model_data(tree_scene)
	if tree_data.mesh == null:
		push_error("BorderTreeWall: Impossible d'extraire le Mesh depuis tree_scene !")
		_is_generating = false
		return
		
	var map_w: float = 3072.0
	var map_h: float = 3072.0
	if "map_width_chunks" in map_generator and "region_size" in map_generator:
		map_w = float(map_generator.map_width_chunks * map_generator.region_size)
	if "map_height_chunks" in map_generator and "region_size" in map_generator:
		map_h = float(map_generator.map_height_chunks * map_generator.region_size)
		
	var b_margin: float = 35.0
	if "border_margin" in map_generator:
		b_margin = float(map_generator.border_margin)
		
	var seed_val: int = 12345
	if "world_seed" in map_generator:
		seed_val = map_generator.world_seed
		
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 5544
	
	# Récupération des 4 terminaisons de routes (pour découper des ouvertures)
	var exits: Array[Vector2] = []
	if path_generator != null:
		if path_generator.has_method("get_border_exits"):
			exits = path_generator.get_border_exits()
		elif "start_pos" in path_generator and path_generator.start_pos != Vector2.ZERO:
			exits.append(path_generator.start_pos)
			
	var half_opening: float = road_opening_width * 0.5
	var tree_instances: Array[Dictionary] = []
	var tree_transforms: Array[Transform3D] = []
	
	for r in range(wall_rows):
		var cur_margin: float = b_margin + float(r) * row_spacing
		var stagger: float = (tree_spacing * 0.5) if (r % 2 == 1) else 0.0
		
		# 1. Côté NORD (Z = cur_margin, X varie)
		var x_pos = cur_margin + stagger
		while x_pos <= map_w - cur_margin:
			if not _is_near_any_exit(x_pos, cur_margin, exits, half_opening, 0):
				_create_tree_at(x_pos, cur_margin, rng, tree_data, tree_instances, tree_transforms)
			x_pos += tree_spacing
			
		# 2. Côté SUD (Z = map_h - cur_margin, X varie)
		x_pos = cur_margin + stagger
		while x_pos <= map_w - cur_margin:
			var z_pos = map_h - cur_margin
			if not _is_near_any_exit(x_pos, z_pos, exits, half_opening, 1):
				_create_tree_at(x_pos, z_pos, rng, tree_data, tree_instances, tree_transforms)
			x_pos += tree_spacing
			
		# 3. Côté OUEST (X = cur_margin, Z varie)
		var z_pos = cur_margin + tree_spacing + stagger
		while z_pos < map_h - cur_margin:
			if not _is_near_any_exit(cur_margin, z_pos, exits, half_opening, 2):
				_create_tree_at(cur_margin, z_pos, rng, tree_data, tree_instances, tree_transforms)
			z_pos += tree_spacing
			
		# 4. Côté EST (X = map_w - cur_margin, Z varie)
		z_pos = cur_margin + tree_spacing + stagger
		var x_east = map_w - cur_margin
		while z_pos < map_h - cur_margin:
			if not _is_near_any_exit(x_east, z_pos, exits, half_opening, 3):
				_create_tree_at(x_east, z_pos, rng, tree_data, tree_instances, tree_transforms)
			z_pos += tree_spacing
			
	var count = tree_transforms.size()
	print("BorderTreeWall: ", count, " arbres de mur calculés le long du périmètre.")
	
	if count == 0:
		_is_generating = false
		return
		
	# Construction des MultiMeshInstance3D en chunks
	var chunk_size: float = 256.0
	var chunks: Dictionary = {}
	for i in range(count):
		var t = tree_transforms[i]
		var cx = int(floor(t.origin.x / chunk_size))
		var cz = int(floor(t.origin.z / chunk_size))
		var key = Vector2i(cx, cz)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
		
	for key in chunks.keys():
		var chunk_list = chunks[key]
		var c_count = chunk_list.size()
		var mmi_name = "WallMultiMesh_%d_%d" % [key.x, key.y]
		
		var mmi = get_node_or_null(mmi_name) as MultiMeshInstance3D
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = mmi_name
			add_child(mmi)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				mmi.owner = get_tree().edited_scene_root
				
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_data["mesh"]
		mm.instance_count = c_count
		for i in range(c_count):
			mm.set_instance_transform(i, chunk_list[i])
			
		mmi.multimesh = mm
		if tree_data["material"] != null:
			mmi.material_override = tree_data["material"]
			
		mmi.visibility_range_end = 450.0
		mmi.visibility_range_end_margin = 50.0
		
	# Création des collisions
	if tree_data["shape"] != null:
		_setup_wall_collisions(tree_instances, tree_data)
		
	var time_total = Time.get_ticks_msec() - time_start
	print("BorderTreeWall: Terminé ! %d arbres placés en %d ms." % [count, time_total])
	_is_generating = false
	wall_ready.emit()

func _is_near_any_exit(px: float, pz: float, exits: Array[Vector2], half_opening: float, side: int) -> bool:
	for ex in exits:
		if ex == Vector2.ZERO: continue
		match side:
			0: # Nord : Z proche du bord Nord, vérifier l'alignement en X
				if absf(pz - ex.y) < 80.0 and absf(px - ex.x) < half_opening:
					return true
			1: # Sud : Z proche du bord Sud, vérifier l'alignement en X
				if absf(pz - ex.y) < 80.0 and absf(px - ex.x) < half_opening:
					return true
			2: # Ouest : X proche du bord Ouest, vérifier l'alignement en Z
				if absf(px - ex.x) < 80.0 and absf(pz - ex.y) < half_opening:
					return true
			3: # Est : X proche du bord Est, vérifier l'alignement en Z
				if absf(px - ex.x) < 80.0 and absf(pz - ex.y) < half_opening:
					return true
					
		# Vérification par distance radiale globale au cas où la sortie a un angle
		if Vector2(px, pz).distance_squared_to(ex) < (half_opening * half_opening):
			return true
	return false

func _create_tree_at(base_x: float, base_z: float, rng: RandomNumberGenerator, tree_data: Dictionary, instances: Array[Dictionary], transforms: Array[Transform3D]) -> void:
	var px = base_x + rng.randf_range(-jitter, jitter)
	var pz = base_z + rng.randf_range(-jitter, jitter)
	
	var ground_y = 0.0
	if map_generator != null and map_generator.has_method("get_terrain_height_at"):
		ground_y = map_generator.get_terrain_height_at(px, pz)
		
	var s: float = rng.randf_range(min_scale, max_scale)
	var rot_y: float = rng.randf_range(0.0, TAU)
	
	# Hauteur tenant compte de l'offset du tronc/Marker3D
	var final_y = ground_y - (tree_data["ground_offset"] * s)
	var tree_pos = Vector3(px, final_y, pz)
	
	var rot_basis = Basis(Vector3.UP, rot_y)
	var orient_basis = rot_basis * tree_data["mesh_basis"]
	var visual_basis = orient_basis.scaled(Vector3.ONE * s)
	var visual_pos = tree_pos + rot_basis * (tree_data["mesh_offset"] * s)
	
	transforms.append(Transform3D(visual_basis, visual_pos))
	
	instances.append({
		"pos": tree_pos,
		"scale": s,
		"rot_y": rot_y
	})

func _setup_wall_collisions(instances: Array[Dictionary], tree_data: Dictionary) -> void:
	if use_physics_server:
		var space: RID = get_world_3d().space
		var shape_rid: RID = tree_data["shape"].get_rid()
		
		for inst in instances:
			var s: float = inst["scale"]
			var rot_y: float = inst["rot_y"]
			var pos: Vector3 = inst["pos"]
			
			var body: RID = PhysicsServer3D.body_create()
			if not body.is_valid():
				break
				
			PhysicsServer3D.body_set_space(body, space)
			PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer(body, tree_data["collision_layer"])
			PhysicsServer3D.body_set_collision_mask(body, tree_data["collision_mask"])
			
			var local_shape_t = Transform3D(Basis().scaled(Vector3.ONE * s), tree_data["shape_offset"] * s)
			PhysicsServer3D.body_add_shape(body, shape_rid, local_shape_t)
			
			var body_t = Transform3D(Basis(Vector3.UP, rot_y), pos)
			PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, body_t)
			_physics_body_rids.append(body)
	else:
		var colliders_node = get_node_or_null("WallColliders")
		if colliders_node == null:
			colliders_node = Node3D.new()
			colliders_node.name = "WallColliders"
			add_child(colliders_node)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				colliders_node.owner = get_tree().edited_scene_root
				
		for inst in instances:
			var s: float = inst["scale"]
			var rot_y: float = inst["rot_y"]
			var pos: Vector3 = inst["pos"]
			
			var body = StaticBody3D.new()
			body.collision_layer = tree_data["collision_layer"]
			body.collision_mask = tree_data["collision_mask"]
			body.transform = Transform3D(Basis(Vector3.UP, rot_y), pos)
			
			var col = CollisionShape3D.new()
			col.shape = tree_data["shape"]
			col.scale = Vector3.ONE * s
			col.position = tree_data["shape_offset"] * s
			body.add_child(col)
			colliders_node.add_child(body)

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
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.shape_offset = rel_t.origin
		elif n is Marker3D:
			var curr: Node = n
			var rel_t: Transform3D = Transform3D.IDENTITY
			while curr != null and curr != inst:
				if curr is Node3D:
					rel_t = curr.transform * rel_t
				curr = curr.get_parent()
			result.ground_offset = rel_t.origin.y
			
	inst.queue_free()
	return result
