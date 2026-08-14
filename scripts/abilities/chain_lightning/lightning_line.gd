class_name LightningLine
extends Node3D

var start_node: Node3D
var end_node: Node3D
var duration: float = 0.5
var thickness: float = 0.1
var spread: float = 0.5 # L'ampleur des zig-zags (anciennement l'écartement)

var sphere_radius: float = 0.5
var sphere_material: Material
var start_sphere: MeshInstance3D

var segments_count: int = 8
# meshes_arrays contient 3 tableaux (un pour chaque ligne), chaque tableau contenant ses segments
var meshes_arrays: Array = [[], [], []]

func setup(p_start: Node3D, p_end: Node3D, p_duration: float = 0.5, p_thickness: float = 0.1, p_spread: float = 0.5, mat1: Material = null, mat2: Material = null, mat3: Material = null, s_rad: float = 0.5, s_mat: Material = null) -> void:
	start_node = p_start
	end_node = p_end
	duration = p_duration
	thickness = p_thickness
	spread = p_spread
	sphere_radius = s_rad
	sphere_material = s_mat
	
	var materials = [mat1, mat2, mat3]
	
	for i in range(3):
		for j in range(segments_count):
			var mesh_instance = MeshInstance3D.new()
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = thickness
			cylinder.bottom_radius = thickness
			cylinder.height = 1.0 
			# Réduire les segments pour optimiser vu qu'on en génère beaucoup
			cylinder.radial_segments = 4 
			cylinder.rings = 1
			
			mesh_instance.mesh = cylinder
			if materials[i] != null:
				mesh_instance.material_override = materials[i]
			
			# Rotation de base
			mesh_instance.rotation_degrees.x = 90
			
			meshes_arrays[i].append(mesh_instance)
			add_child(mesh_instance)

func _ready() -> void:
	if not is_instance_valid(start_node) or not is_instance_valid(end_node):
		queue_free()
		return
		
	if start_node is Marker3D:
		start_sphere = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = sphere_radius
		sphere.height = sphere_radius * 2.0
		start_sphere.mesh = sphere
		if sphere_material != null:
			start_sphere.material_override = sphere_material
		add_child(start_sphere)
		
	# Détruire la ligne après la durée
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _process(delta: float) -> void:
	if not is_instance_valid(start_node) or not is_instance_valid(end_node):
		return
		
	var pos_start = start_node.global_position
	if not start_node is Marker3D:
		pos_start.y += 1.0 
		
	var pos_end = end_node.global_position
	if not end_node is Marker3D:
		pos_end.y += 1.0
		
	if start_sphere != null and is_instance_valid(start_sphere):
		start_sphere.global_position = pos_start
	
	var distance = pos_start.distance_to(pos_end)
	if distance < 0.01:
		return
		
	var dir = (pos_end - pos_start).normalized()
	
	# Pour chaque ligne électrique (3 au total)
	for i in range(3):
		# Générer les points intermédiaires avec du bruit (vibration)
		var points = []
		points.append(pos_start)
		
		var segment_length = distance / segments_count
		for j in range(1, segments_count):
			var base_point = pos_start + dir * (segment_length * j)
			# Ajouter un décalage aléatoire perpendiculaire pour le zig-zag
			var random_offset = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized() * randf_range(0.0, spread)
			points.append(base_point + random_offset)
			
		points.append(pos_end)
		
		# Placer les cylindres entre ces points
		var segments = meshes_arrays[i]
		for j in range(segments_count):
			var p1 = points[j]
			var p2 = points[j+1]
			
			var seg_dist = p1.distance_to(p2)
			var m = segments[j]
			
			# Met à jour la longueur du petit segment
			if m.mesh is CylinderMesh:
				m.mesh.height = seg_dist
				
			# Place au milieu
			m.global_position = p1.lerp(p2, 0.5)
			
			# Oriente vers le point suivant
			var seg_dir = (p2 - p1).normalized()
			if seg_dir.is_normalized():
				# Réinitialiser la rotation pour éviter les conflits avec look_at
				m.transform.basis = Basis()
				m.look_at_from_position(m.global_position, m.global_position + seg_dir, Vector3.UP)
				m.rotation_degrees.x += 90
