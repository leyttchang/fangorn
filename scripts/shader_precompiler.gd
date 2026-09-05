extends CanvasLayer

var folders_to_scan = [
	"res://scripts/abilities",
	"res://scripts/status_effects",
	"res://particule",
	"res://assets"
]

@onready var container = Node3D.new()
@onready var camera = Camera3D.new()

func _ready():
	# UI Noir pour cacher le chargement
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Setup de la camera pour forcer le rendu
	add_child(camera)
	camera.make_current()
	
	add_child(container)
	container.position.z = -5 # Devant la camera
	
	# IMPORTANT : On laisse le temps a Godot de dessiner l'ecran noir AVANT de freeze !
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Precompiler] Demarrage de la precompilation des shaders...")
	
	var all_files = []
	for folder in folders_to_scan:
		_find_files_recursively(folder, all_files)
		
	var spawned_count = 0
	var dummy_mesh_count = 0
	
	# Un mesh basique pour tester les materiaux
	var dummy_mesh = SphereMesh.new()
	
	for file_path in all_files:
		var res = load(file_path)
		if res is PackedScene:
			var instance = res.instantiate()
			
			# 1. On recupere tous les materiaux caches dans les variables des scripts du sort !
			_extract_materials_from_node_properties(instance, container, dummy_mesh)
			
			# 2. On retire les scripts pour eviter les crashs
			_remove_scripts_recursively(instance)
			
			container.add_child(instance)
			_force_particles_emit(instance)
			spawned_count += 1
			
		elif res is Material:
			# Si c'est un material libre (.tres)
			_create_dummy_mesh(res, container, dummy_mesh)
			dummy_mesh_count += 1
			
		elif res is Resource:
			# Si c'est un StatusEffectData ou autre, on cherche dedans
			_extract_materials_from_resource(res, container, dummy_mesh)
			
	print("[Precompiler] " + str(spawned_count) + " scenes et " + str(dummy_mesh_count) + " materiaux isoles instancies. Attente...")
	
	# On attend 3 frames pour etre sur que la carte graphique a tout rendu
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Precompiler] Compilation terminee !")
	
	# On charge ton vrai menu principal (l'ancienne scene principale du jeu)
	get_tree().change_scene_to_file("uid://cpvcfdqrbu4i4")
	
	queue_free()

func _find_files_recursively(path: String, result: Array):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_find_files_recursively(path + "/" + file_name, result)
			else:
				if file_name.ends_with(".tscn") or file_name.ends_with(".tres") or file_name.ends_with(".material"):
					result.append(path + "/" + file_name)
			file_name = dir.get_next()

func _create_dummy_mesh(mat: Material, parent: Node, mesh: Mesh):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)

func _extract_materials_from_node_properties(node: Node, parent: Node, mesh: Mesh):
	for prop in node.get_property_list():
		if prop.type == TYPE_OBJECT:
			# Fix pour les GPUParticles3D qui plantent quand on get("draw_pass_2") alors qu'ils n'en ont qu'un
			if node is GPUParticles3D and prop.name.begins_with("draw_pass_"):
				var pass_index = prop.name.trim_prefix("draw_pass_").to_int()
				if pass_index > node.draw_passes:
					continue
					
			var val = node.get(prop.name)
			if val is Material:
				_create_dummy_mesh(val, parent, mesh)
			elif val is Resource:
				_extract_materials_from_resource(val, parent, mesh)
			
	for child in node.get_children():
		_extract_materials_from_node_properties(child, parent, mesh)

func _extract_materials_from_resource(res: Resource, parent: Node, mesh: Mesh):
	for prop in res.get_property_list():
		if prop.type == TYPE_OBJECT:
			var val = res.get(prop.name)
			if val is Material:
				_create_dummy_mesh(val, parent, mesh)

func _remove_scripts_recursively(node: Node):
	node.set_script(null)
	node.set_process(false)
	node.set_physics_process(false)
	
	# FIX: Empeche les erreurs "det == 0" pour les scenes sauvegardees avec un scale de (0,0,0)
	if node is Node3D:
		if node.scale.x == 0 or node.scale.y == 0 or node.scale.z == 0:
			node.scale = Vector3(0.01, 0.01, 0.01)
			
	for child in node.get_children():
		_remove_scripts_recursively(child)

func _force_particles_emit(node: Node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = true
		node.one_shot = false
	for child in node.get_children():
		_force_particles_emit(child)
