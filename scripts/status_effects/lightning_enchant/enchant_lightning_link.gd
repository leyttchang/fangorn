class_name EnchantLightningLink
extends Node3D

## Arc électrique optimisé en 2 phases entre deux monstres enchantés :
## - 0 OmniLight3D Forward+, 2 brins × 6 segments partagés, recalcul zig-zag cadencé (~28 Hz)
## - Phase 1 (Télégraphe, ~1.0s) : fine chaîne qui pulse entre les deux monstres en mouvement (sans dégâts)
## - Phase 2 (Décharge, ~0.38s) : devient brusquement large + éclats plafonnés + dégâts foudre aux joueurs touchés

const MAX_STRANDS := 2
const JITTER_INTERVAL := 0.036
const MAX_CONCURRENT_SPARK_BURSTS := 6

static var _unit_cylinder: CylinderMesh
static var _unit_sphere: SphereMesh
static var _active_spark_bursts: int = 0

var start_node: Node3D
var end_node: Node3D

var telegraph_duration: float = 1.0
var strike_duration: float = 0.38
var telegraph_thickness: float = 0.026
var strike_thickness: float = 0.145
var telegraph_spread: float = 0.11
var strike_spread: float = 0.35
var segments_count: int = 6

var sparks_scene: PackedScene
var strike_damage_callback: Callable = Callable()

var _meshes_arrays: Array = [[], []]
var _start_sphere: MeshInstance3D
var _end_sphere: MeshInstance3D

var _elapsed: float = 0.0
var _jitter_accum: float = JITTER_INTERVAL
var _strike_triggered: bool = false
var _last_pos_start: Vector3 = Vector3.ZERO
var _last_pos_end: Vector3 = Vector3.ZERO


static func _ensure_shared_meshes() -> void:
	if _unit_cylinder == null:
		_unit_cylinder = CylinderMesh.new()
		_unit_cylinder.top_radius = 1.0
		_unit_cylinder.bottom_radius = 1.0
		_unit_cylinder.height = 1.0
		_unit_cylinder.radial_segments = 4
		_unit_cylinder.rings = 0
		_unit_cylinder.cap_top = false
		_unit_cylinder.cap_bottom = false
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 1.0
		_unit_sphere.height = 2.0
		_unit_sphere.radial_segments = 6
		_unit_sphere.rings = 3


func setup(
	p_start: Node3D,
	p_end: Node3D,
	config: Dictionary,
	mat1: Material,
	mat2: Material,
	_mat3: Material,
	sphere_mat: Material,
	p_sparks_scene: PackedScene = null,
	p_damage_cb: Callable = Callable()
) -> void:
	_ensure_shared_meshes()

	start_node = p_start
	end_node = p_end
	telegraph_duration = maxf(0.1, float(config.get("telegraph_duration", 1.0)))
	strike_duration = maxf(0.1, float(config.get("strike_duration", 0.38)))
	telegraph_thickness = maxf(0.005, float(config.get("telegraph_thickness", 0.028)))
	strike_thickness = maxf(0.02, float(config.get("strike_thickness", 0.17)))
	telegraph_spread = maxf(0.01, float(config.get("telegraph_spread", 0.11)))
	strike_spread = maxf(0.02, float(config.get("strike_spread", 0.38)))
	segments_count = clampi(int(config.get("segments_count", 6)), 4, 9)
	sparks_scene = p_sparks_scene
	strike_damage_callback = p_damage_cb

	var materials: Array[Material] = [mat1, mat2 if mat2 != null else mat1]

	for i in range(MAX_STRANDS):
		for _j in range(segments_count):
			var mi := MeshInstance3D.new()
			mi.mesh = _unit_cylinder
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 65.0
			if materials[i] != null:
				mi.material_override = materials[i]
			mi.visible = false
			_meshes_arrays[i].append(mi)
			add_child(mi)

	_start_sphere = MeshInstance3D.new()
	_start_sphere.mesh = _unit_sphere
	_start_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_start_sphere.visibility_range_end = 58.0
	if sphere_mat != null:
		_start_sphere.material_override = sphere_mat
	add_child(_start_sphere)

	_end_sphere = MeshInstance3D.new()
	_end_sphere.mesh = _unit_sphere
	_end_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_end_sphere.visibility_range_end = 58.0
	if sphere_mat != null:
		_end_sphere.material_override = sphere_mat
	add_child(_end_sphere)


func _ready() -> void:
	if _is_mob_invalid_or_dead(start_node) or _is_mob_invalid_or_dead(end_node):
		queue_free()
		return
	_last_pos_start = get_body_anchor_pos(start_node)
	_last_pos_end = get_body_anchor_pos(end_node)


func _process(delta: float) -> void:
	_elapsed += delta
	var total_dur: float = telegraph_duration + strike_duration
	if _elapsed >= total_dur:
		queue_free()
		return

	var in_strike: bool = (_elapsed >= telegraph_duration)

	if not in_strike:
		# Si l'un des deux monstres est tué pendant la seconde de pré-charge, le lien est rompu !
		if _is_mob_invalid_or_dead(start_node) or _is_mob_invalid_or_dead(end_node):
			queue_free()
			return
		_last_pos_start = get_body_anchor_pos(start_node)
		_last_pos_end = get_body_anchor_pos(end_node)
	else:
		if not _is_mob_invalid_or_dead(start_node):
			_last_pos_start = get_body_anchor_pos(start_node)
		if not _is_mob_invalid_or_dead(end_node):
			_last_pos_end = get_body_anchor_pos(end_node)

	var pos_start: Vector3 = _last_pos_start
	var pos_end: Vector3 = _last_pos_end
	var distance: float = pos_start.distance_to(pos_end)
	if distance < 0.05:
		return

	var force_rebuild: bool = false
	if in_strike and not _strike_triggered:
		_strike_triggered = true
		force_rebuild = true
		_spawn_strike_sparks(pos_start.lerp(pos_end, 0.5))

	# Vérification continue des dégâts pendant la fenêtre active du flash électrique
	if in_strike:
		var s_dmg: float = clampf((_elapsed - telegraph_duration) / strike_duration, 0.0, 1.0)
		if s_dmg <= 0.52 and strike_damage_callback.is_valid():
			strike_damage_callback.call(pos_start, pos_end)

	# Cadence le recalcul géométrique du zig-zag à ~28 Hz pour éviter de recalculer 500 Basis à 144+ FPS
	_jitter_accum += delta
	if not force_rebuild and _jitter_accum < JITTER_INTERVAL:
		return
	_jitter_accum = 0.0

	var cur_thickness: float
	var cur_spread: float
	var active_strands: int = MAX_STRANDS
	var sphere_scale: float

	if not in_strike:
		var u: float = clampf(_elapsed / telegraph_duration, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(u * TAU * (3.5 + u * 2.5))
		cur_thickness = telegraph_thickness * lerpf(0.50, 1.45, pulse) * lerpf(0.85, 1.35, u)
		cur_spread = telegraph_spread * lerpf(0.65, 1.30, u) * (0.70 + 0.30 * pulse)
		active_strands = 1 if u < 0.62 else 2
		sphere_scale = cur_thickness * 3.4
	else:
		var s: float = clampf((_elapsed - telegraph_duration) / strike_duration, 0.0, 1.0)
		var width_env: float
		if s < 0.08:
			width_env = lerpf(0.45, 1.0, s / 0.08)
		elif s <= 0.44:
			width_env = 1.0
		else:
			width_env = pow(maxf(0.0, 1.0 - ((s - 0.44) / 0.56)), 1.55)

		cur_thickness = maxf(0.003, strike_thickness * width_env)
		cur_spread = strike_spread * lerpf(1.0, 0.35, s)
		active_strands = MAX_STRANDS
		sphere_scale = cur_thickness * 2.1

	_start_sphere.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sphere_scale), pos_start)
	_end_sphere.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sphere_scale), pos_end)

	var dir: Vector3 = (pos_end - pos_start) / distance
	var segment_len: float = distance / float(segments_count)

	for i in range(MAX_STRANDS):
		var segments: Array = _meshes_arrays[i]
		if i >= active_strands:
			for seg_mesh in segments:
				(seg_mesh as MeshInstance3D).visible = false
			continue

		var points := PackedVector3Array()
		points.resize(segments_count + 1)
		points[0] = pos_start
		points[segments_count] = pos_end

		var strand_thick: float = cur_thickness * (1.0 if i == 0 else 0.80)

		for j in range(1, segments_count):
			var base_pt: Vector3 = pos_start + dir * (segment_len * float(j))
			var arch: float = sin((float(j) / float(segments_count)) * PI)
			var rnd := Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.75, 0.75),
				randf_range(-1.0, 1.0)
			)
			if rnd.length_squared() > 0.001:
				rnd = rnd.normalized() * randf_range(0.15, 1.0) * cur_spread * (0.35 + 0.65 * arch)
			points[j] = base_pt + rnd

		for j in range(segments_count):
			var p1: Vector3 = points[j]
			var p2: Vector3 = points[j + 1]
			var delta_seg: Vector3 = p2 - p1
			var seg_dist: float = delta_seg.length()
			var m := segments[j] as MeshInstance3D
			if seg_dist < 0.002:
				m.visible = false
				continue

			m.visible = true
			var y_axis: Vector3 = delta_seg / seg_dist
			var ref_up: Vector3 = Vector3.UP if absf(y_axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			var x_axis: Vector3 = ref_up.cross(y_axis).normalized()
			var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
			var seg_basis := Basis(x_axis * strand_thick, y_axis * seg_dist, z_axis * strand_thick)
			m.global_transform = Transform3D(seg_basis, p1.lerp(p2, 0.5))


func _spawn_strike_sparks(world_pos: Vector3) -> void:
	if sparks_scene == null or get_tree() == null:
		return
	if _active_spark_bursts >= MAX_CONCURRENT_SPARK_BURSTS:
		return

	var sp := sparks_scene.instantiate() as GPUParticles3D
	if sp == null:
		return

	_active_spark_bursts += 1
	var scene_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_parent.add_child(sp)
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_range_end = 48.0
	sp.global_position = world_pos
	sp.one_shot = true
	sp.explosiveness = 0.92
	sp.amount = 14
	sp.fixed_fps = 30
	sp.emitting = true
	get_tree().create_timer(0.65).timeout.connect(func() -> void:
		_active_spark_bursts = maxi(0, _active_spark_bursts - 1)
		if is_instance_valid(sp):
			sp.queue_free()
	)


static func get_body_anchor_pos(mob: Node3D) -> Vector3:
	if mob == null or not is_instance_valid(mob):
		return Vector3.ZERO
	var cs := mob.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		if cs.position.y < 0.05:
			return cs.global_position
		return mob.global_position + Vector3(cs.position.x, clampf(cs.position.y, 0.38, 1.40), cs.position.z)
	return mob.global_position + Vector3(0.0, 1.0, 0.0)


static func _is_mob_invalid_or_dead(mob: Node3D) -> bool:
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
		return true
	var hc := mob.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in mob and "State" in mob and "DEAD" in mob.State:
		if mob.current_state == mob.State.DEAD:
			return true
	return false
