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
var _points_buf: PackedVector3Array = PackedVector3Array()
var _rad_scale: float = 1.0

static var _unit_strand_mesh_0: CylinderMesh = null
static var _unit_strand_mesh_1: CylinderMesh = null
static var _unit_strand_mesh_2: CylinderMesh = null
static var _unit_strand_radius: float = -1.0
static var _unit_start_sphere_mesh: SphereMesh = null

static func _get_unit_strand_meshes(base_radius: float) -> Array[CylinderMesh]:
	if _unit_strand_mesh_0 == null or _unit_strand_mesh_1 == null or _unit_strand_mesh_2 == null:
		_unit_strand_radius = maxf(0.001, base_radius)
		_unit_strand_mesh_0 = _create_unit_cylinder(_unit_strand_radius)
		_unit_strand_mesh_1 = _create_unit_cylinder(_unit_strand_radius)
		_unit_strand_mesh_2 = _create_unit_cylinder(_unit_strand_radius)
	return [_unit_strand_mesh_0, _unit_strand_mesh_1, _unit_strand_mesh_2]

static func _create_unit_cylinder(rad: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = rad
	cylinder.bottom_radius = rad
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.rings = 1
	return cylinder

func setup(p_start: Node3D, p_end: Node3D, p_duration: float = 0.5, p_thickness: float = 0.1, p_spread: float = 0.5, mat1: Material = null, mat2: Material = null, mat3: Material = null, s_rad: float = 0.5, s_mat: Material = null) -> void:
	start_node = p_start
	end_node = p_end
	duration = p_duration
	thickness = maxf(0.001, p_thickness)
	spread = p_spread
	sphere_radius = s_rad
	sphere_material = s_mat

	_points_buf.resize(segments_count + 1)
	var strand_meshes := _get_unit_strand_meshes(thickness)
	_rad_scale = thickness / _unit_strand_radius if _unit_strand_radius > 0.0 else 1.0

	var materials := [mat1, mat2, mat3]

	for i in range(3):
		var unit_mesh: CylinderMesh = strand_meshes[i]
		var strand_mat: Material = materials[i]
		for j in range(segments_count):
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = unit_mesh
			if strand_mat != null:
				mesh_instance.material_override = strand_mat

			# Rotation de base
			mesh_instance.rotation_degrees.x = 90.0

			meshes_arrays[i].append(mesh_instance)
			add_child(mesh_instance)

func _ready() -> void:
	if not is_instance_valid(start_node) or not is_instance_valid(end_node):
		queue_free()
		return

	if _points_buf.size() != segments_count + 1:
		_points_buf.resize(segments_count + 1)

	if start_node is Marker3D:
		start_sphere = MeshInstance3D.new()
		if _unit_start_sphere_mesh == null:
			_unit_start_sphere_mesh = SphereMesh.new()
			_unit_start_sphere_mesh.radius = 1.0
			_unit_start_sphere_mesh.height = 2.0
		start_sphere.mesh = _unit_start_sphere_mesh
		start_sphere.scale = Vector3.ONE * maxf(0.001, sphere_radius)
		if sphere_material != null:
			start_sphere.material_override = sphere_material
		add_child(start_sphere)

	# Détruire la ligne après la durée
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _process(_delta: float) -> void:
	if not is_instance_valid(start_node) or not is_instance_valid(end_node):
		return

	var pos_start: Vector3 = start_node.global_position
	if not start_node is Marker3D:
		pos_start.y += 1.0

	var pos_end: Vector3 = end_node.global_position
	if not end_node is Marker3D:
		pos_end.y += 1.0

	if start_sphere != null and is_instance_valid(start_sphere):
		start_sphere.global_position = pos_start

	var distance: float = pos_start.distance_to(pos_end)
	if distance < 0.01:
		return

	if _points_buf.size() != segments_count + 1:
		_points_buf.resize(segments_count + 1)

	var dir: Vector3 = (pos_end - pos_start) / distance
	var segment_length: float = distance / float(segments_count)

	# Pour chaque ligne électrique (3 au total)
	for i in range(3):
		# Générer les points intermédiaires avec du bruit (vibration) sans allocation par frame
		_points_buf[0] = pos_start
		for j in range(1, segments_count):
			var base_point: Vector3 = pos_start + dir * (segment_length * float(j))
			# Ajouter un décalage aléatoire pour le zig-zag
			var random_offset: Vector3 = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized() * randf_range(0.0, spread)
			_points_buf[j] = base_point + random_offset
		_points_buf[segments_count] = pos_end

		# Placer et étirer les cylindres unitaires entre ces points via m.scale (0 rebuild GPU)
		var segments: Array = meshes_arrays[i]
		for j in range(segments_count):
			var p1: Vector3 = _points_buf[j]
			var p2: Vector3 = _points_buf[j + 1]

			var seg_vec: Vector3 = p2 - p1
			var seg_dist: float = seg_vec.length()
			var m: MeshInstance3D = segments[j]
			var mid_pos: Vector3 = p1.lerp(p2, 0.5)

			if seg_dist > 0.0001:
				var seg_dir: Vector3 = seg_vec / seg_dist
				var up_vec: Vector3 = Vector3.UP if absf(seg_dir.y) < 0.99 else Vector3.RIGHT
				m.transform.basis = Basis()
				m.look_at_from_position(mid_pos, mid_pos + seg_dir, up_vec)
				m.rotation_degrees.x += 90.0
			else:
				m.global_position = mid_pos

			m.scale = Vector3(_rad_scale, maxf(0.0001, seg_dist), _rad_scale)
