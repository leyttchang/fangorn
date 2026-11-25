extends Node3D

static var _shard_quad: PrismMesh = null
static var _shard_mat: StandardMaterial3D = null
static var _shard_proc: ParticleProcessMaterial = null
static var _wave_mesh: BoxMesh = null
static var _wave_mat: StandardMaterial3D = null
static var _cone_sphere_cache: Dictionary = {}

@export var cone_range: float = 5.5
@export var cone_angle_deg: float = 78.0

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _wave_visual: Node3D = null


static func _ensure_shared_visuals() -> void:
	if _shard_quad == null:
		_shard_quad = PrismMesh.new()
		_shard_quad.size = Vector3(0.14, 0.32, 0.08)

	if _shard_mat == null:
		_shard_mat = StandardMaterial3D.new()
		_shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shard_mat.vertex_color_use_as_albedo = true
		_shard_mat.albedo_color = Color(0.75, 1.85, 2.8, 0.9)

	if _shard_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.particle_flag_align_y = true
		pm.direction = Vector3(0.0, 0.08, -1.0)
		pm.spread = 38.0
		pm.initial_velocity_min = 11.0
		pm.initial_velocity_max = 18.5
		pm.damping_min = 18.0
		pm.damping_max = 26.0
		pm.gravity = Vector3(0.0, -2.0, 0.0)
		pm.scale_min = 0.55
		pm.scale_max = 1.15
		pm.color = Color(0.72, 1.75, 2.75, 0.95)
		_shard_proc = pm

	if _wave_mesh == null:
		_wave_mesh = BoxMesh.new()
		_wave_mesh.size = Vector3(0.22, 0.06, 1.1)

	if _wave_mat == null:
		_wave_mat = StandardMaterial3D.new()
		_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wave_mat.albedo_color = Color(0.55, 1.65, 2.6, 0.65)


static func _get_cached_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(10, int(roundf(rad * 10.0)))
	if _cone_sphere_cache.has(key):
		return _cone_sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 10.0
	_cone_sphere_cache[key] = sph
	return sph


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	var fwd: Vector3 = -caster.global_transform.basis.z
	var cam: Camera3D = caster.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		fwd = -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	global_position = caster.global_position + Vector3(0.0, 0.95, 0.0)
	look_at(global_position + fwd, Vector3.UP)

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)

	var final_range: float = scaling_component.final_impact_radius if scaling_component != null else cone_range
	var scale_mult: float = final_range / maxf(0.5, cone_range)

	# Burst de cristaux de givre dans le cône frontal
	var burst: GPUParticles3D = GPUParticles3D.new()
	burst.material_override = _shard_mat
	burst.process_material = _shard_proc
	burst.draw_pass_1 = _shard_quad
	burst.amount = 26
	burst.lifetime = 0.34
	burst.one_shot = true
	burst.explosiveness = 0.94
	burst.fixed_fps = 30
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.scale = Vector3.ONE * scale_mult
	add_child(burst)
	burst.emitting = true

	# Eventail de stries glacées au sol matérialisant le cône
	_wave_visual = Node3D.new()
	_wave_visual.position = Vector3(0.0, -0.78, 0.0)
	add_child(_wave_visual)
	for i: int in range(-2, 3):
		var ray_ang: float = deg_to_rad(float(i) * 16.0)
		var streak: MeshInstance3D = MeshInstance3D.new()
		streak.mesh = _wave_mesh
		streak.material_override = _wave_mat
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.rotation.y = ray_ang
		streak.position = Vector3(-sin(ray_ang) * 1.4, 0.0, -cos(ray_ang) * 1.4)
		_wave_visual.add_child(streak)

	var tw: Tween = create_tween()
	tw.tween_property(_wave_visual, "scale", Vector3(scale_mult * 1.65, 1.0, scale_mult * 2.1), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _wave_visual != null:
			_wave_visual.visible = false
	)

	SpellAudioManager.play_ice_cast(self, global_position, 1.18, -1.2)

	var is_auth: bool = (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())
	if is_auth and attack_component != null:
		_apply_cone_hit(caster, fwd, final_range)

	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _apply_cone_hit(caster: Node3D, fwd: Vector3, max_dist: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return

	var origin: Vector3 = caster.global_position + Vector3(0.0, 0.9, 0.0)
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _get_cached_sphere(max_dist)
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var min_dot: float = cos(deg_to_rad(cone_angle_deg * 0.5))
	var hits: Array[Dictionary] = space_state.intersect_shape(params, 24)
	attack_component.global_position = caster.global_position

	var seen: Dictionary = {}
	for entry: Dictionary in hits:
		var hb: HitboxComponent = entry.get("collider") as HitboxComponent
		if hb == null:
			continue
		var entity: Node3D = (hb.owner if hb.owner != null else hb.get_parent()) as Node3D
		if entity == null or entity == caster or entity.is_in_group("Player"):
			continue
		var eid: int = entity.get_instance_id()
		if seen.has(eid):
			continue

		var to_mob: Vector3 = entity.global_position - caster.global_position
		to_mob.y = 0.0
		var dist: float = to_mob.length()
		if dist > max_dist + 0.6:
			continue
		# À bout portant (< 1.15m), touche toujours devant soi ; sinon vérifie l'angle du cône
		if dist > 1.15:
			var dir_to_mob: Vector3 = to_mob / dist
			if fwd.dot(dir_to_mob) < min_dot:
				continue

		seen[eid] = true
		hb.receive_hit(attack_component)
