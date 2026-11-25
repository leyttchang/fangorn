extends Node3D

enum BombPhase { FLYING, IMPLANTED, DETONATED }

const SWELL_SHADER_PATH: String = "res://scripts/abilities/living_bomb/living_bomb_swell.gdshader"
const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"
const SPARK_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"

const META_ORIG_CAPTURED: String = "lb_orig_captured"
const META_ORIG_OVERRIDE: String = "lb_orig_override"
const META_ORIG_SURF0: String = "lb_orig_surf0"
const META_REF_COUNT: String = "lb_ref_count"

static var _seed_core_mesh: SphereMesh = null
static var _seed_shell_mesh: SphereMesh = null
static var _blast_sphere_mesh: SphereMesh = null
static var _blast_ring_mesh: TorusMesh = null
static var _seed_core_mat: StandardMaterial3D = null
static var _seed_shell_mat: StandardMaterial3D = null
static var _trail_quad: QuadMesh = null
static var _trail_mat: StandardMaterial3D = null
static var _trail_proc: ParticleProcessMaterial = null
static var _burst_quad: QuadMesh = null
static var _burst_mat: StandardMaterial3D = null
static var _burst_proc: ParticleProcessMaterial = null
static var _swell_shader: Shader = null
static var _sweep_sphere: SphereShape3D = null

@export var projectile_speed: float = 30.0
@export var max_flight_range: float = 24.0
@export var fuse_duration: float = 2.0
@export var base_swell_radius: float = 1.15
@export var max_swell_amount: float = 0.38
@export var host_bonus_damage_ratio: float = 0.55

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _phase: BombPhase = BombPhase.FLYING
var _caster: Node3D = null
var _is_auth: bool = true

var _fly_dir: Vector3 = Vector3.FORWARD
var _dist_travelled: float = 0.0
var _flight_time: float = 0.0

var _host_mob: Node3D = null
var _local_hit_offset: Vector3 = Vector3.ZERO
var _last_seed_world_pos: Vector3 = Vector3.ZERO
var _fuse_elapsed: float = 0.0
var _effective_swell_radius: float = 1.15

var _seed_core_mi: MeshInstance3D = null
var _seed_shell_mi: MeshInstance3D = null
var _trail_particles: GPUParticles3D = null

var _implanted_meshes: Array[MeshInstance3D] = []
var _active_swell_mats: Array[ShaderMaterial] = []
var _materials_applied: bool = false


static func _ensure_shared_resources() -> void:
	if _seed_core_mesh == null:
		_seed_core_mesh = SphereMesh.new()
		_seed_core_mesh.radius = 0.12
		_seed_core_mesh.height = 0.24
		_seed_core_mesh.radial_segments = 10
		_seed_core_mesh.rings = 5

	if _seed_shell_mesh == null:
		_seed_shell_mesh = SphereMesh.new()
		_seed_shell_mesh.radius = 0.19
		_seed_shell_mesh.height = 0.38
		_seed_shell_mesh.radial_segments = 10
		_seed_shell_mesh.rings = 5

	if _blast_sphere_mesh == null:
		_blast_sphere_mesh = SphereMesh.new()
		_blast_sphere_mesh.radius = 1.0
		_blast_sphere_mesh.height = 2.0
		_blast_sphere_mesh.radial_segments = 20
		_blast_sphere_mesh.rings = 10

	if _blast_ring_mesh == null:
		_blast_ring_mesh = TorusMesh.new()
		_blast_ring_mesh.inner_radius = 0.78
		_blast_ring_mesh.outer_radius = 1.0
		_blast_ring_mesh.rings = 20
		_blast_ring_mesh.ring_segments = 6

	if _seed_core_mat == null:
		_seed_core_mat = StandardMaterial3D.new()
		_seed_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_seed_core_mat.albedo_color = Color(3.4, 1.85, 0.42, 1.0)

	if _seed_shell_mat == null:
		_seed_shell_mat = StandardMaterial3D.new()
		_seed_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_seed_shell_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_seed_shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_seed_shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_seed_shell_mat.albedo_color = Color(2.4, 0.52, 0.08, 0.68)

	if _trail_quad == null:
		_trail_quad = QuadMesh.new()
		_trail_quad.size = Vector2(0.24, 0.24)

	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			_trail_mat.albedo_texture = load(FIRE_TEX_PATH) as Texture2D
		_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_trail_mat.billboard_keep_scale = true

	if _trail_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 0.0, 1.0)
		pm.spread = 24.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.9
		pm.gravity = Vector3(0.0, 0.6, 0.0)
		pm.scale_min = 0.35
		pm.scale_max = 0.85
		pm.color = Color(2.6, 1.05, 0.22, 0.9)
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.94, 0.58, 1.0),
			Color(1.0, 0.36, 0.05, 0.82),
			Color(0.65, 0.06, 0.01, 0.0)
		])
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp
		_trail_proc = pm

	if _burst_quad == null:
		_burst_quad = QuadMesh.new()
		_burst_quad.size = Vector2(0.36, 0.36)

	if _burst_mat == null:
		_burst_mat = StandardMaterial3D.new()
		_burst_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_burst_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_mat.vertex_color_use_as_albedo = true
		_burst_mat.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			_burst_mat.albedo_texture = load(FIRE_TEX_PATH) as Texture2D
		elif ResourceLoader.exists(SPARK_TEX_PATH):
			_burst_mat.albedo_texture = load(SPARK_TEX_PATH) as Texture2D
		_burst_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_burst_mat.billboard_keep_scale = true

	if _burst_proc == null:
		var bpm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		bpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		bpm.emission_sphere_radius = 0.35
		bpm.direction = Vector3.UP
		bpm.spread = 180.0
		bpm.initial_velocity_min = 4.5
		bpm.initial_velocity_max = 11.5
		bpm.damping_min = 4.0
		bpm.damping_max = 8.5
		bpm.gravity = Vector3(0.0, -5.5, 0.0)
		bpm.scale_min = 0.45
		bpm.scale_max = 1.25
		bpm.color = Color(2.9, 1.35, 0.32, 1.0)
		var bgrad: Gradient = Gradient.new()
		bgrad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
		bgrad.colors = PackedColorArray([
			Color(1.0, 0.96, 0.68, 1.0),
			Color(1.0, 0.38, 0.05, 0.88),
			Color(0.55, 0.05, 0.01, 0.0)
		])
		var bramp: GradientTexture1D = GradientTexture1D.new()
		bramp.gradient = bgrad
		bpm.color_ramp = bramp
		_burst_proc = bpm

	if _swell_shader == null and ResourceLoader.exists(SWELL_SHADER_PATH):
		_swell_shader = load(SWELL_SHADER_PATH) as Shader

	if _sweep_sphere == null:
		_sweep_sphere = SphereShape3D.new()
		_sweep_sphere.radius = 0.28


func _ready() -> void:
	_ensure_shared_resources()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_seed_core_mi = MeshInstance3D.new()
	_seed_core_mi.mesh = _seed_core_mesh
	_seed_core_mi.material_override = _seed_core_mat
	_seed_core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seed_core_mi)

	_seed_shell_mi = MeshInstance3D.new()
	_seed_shell_mi.mesh = _seed_shell_mesh
	_seed_shell_mi.material_override = _seed_shell_mat
	_seed_shell_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seed_shell_mi)

	_trail_particles = GPUParticles3D.new()
	_trail_particles.material_override = _trail_mat
	_trail_particles.process_material = _trail_proc
	_trail_particles.draw_pass_1 = _trail_quad
	_trail_particles.amount = 16
	_trail_particles.lifetime = 0.28
	_trail_particles.fixed_fps = 30
	_trail_particles.visibility_range_end = 48.0
	_trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_particles)

	set_physics_process(false)
	set_process(false)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)

	var ab_data: AbilityData = target_data.get("ability_data") as AbilityData
	if ab_data != null and ab_data.max_range > 1.0:
		max_flight_range = ab_data.max_range

	var hand_node: Node3D = _caster.find_child("MainGauche", true, false) as Node3D
	if hand_node == null:
		hand_node = _caster.find_child("CastPoint", true, false) as Node3D
	var spawn_pos: Vector3 = hand_node.global_position if hand_node != null else (_caster.global_position + Vector3(0.0, 1.38, 0.0))
	global_position = spawn_pos
	_last_seed_world_pos = spawn_pos

	var cam: Camera3D = _caster.get_node_or_null("Camera3D") as Camera3D
	var aim_origin: Vector3 = cam.global_position if cam != null else (_caster.global_position + Vector3(0.0, 1.45, 0.0))
	var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized() if cam != null else -_caster.global_transform.basis.z.normalized()
	if cam_fwd.length_squared() < 0.001:
		cam_fwd = Vector3.FORWARD

	var aim_target: Vector3 = aim_origin + cam_fwd * max_flight_range
	if is_remote and target_data.has("impact_point"):
		aim_target = target_data["impact_point"] as Vector3
	else:
		var ray_node: RayCast3D = _caster.get_node_or_null("Camera3D/RayCast3D") as RayCast3D
		if ray_node != null:
			ray_node.target_position = Vector3(0.0, 0.0, -max_flight_range)
			ray_node.force_raycast_update()
			if ray_node.is_colliding():
				aim_target = ray_node.get_collision_point()

		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space_state != null:
			var aim_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				aim_origin,
				aim_origin + cam_fwd * max_flight_range,
				393 # 1 (sol) | 8 (HitboxEnemie) | 128 (tree) | 256 (enemie)
			)
			aim_query.collide_with_areas = true
			aim_query.collide_with_bodies = true
			var excl: Array[RID] = []
			var caster_col: CollisionObject3D = _caster as CollisionObject3D
			if caster_col != null:
				excl.append(caster_col.get_rid())
			var caster_hb: Area3D = _caster.get_node_or_null("HitboxComponent") as Area3D
			if caster_hb != null:
				excl.append(caster_hb.get_rid())
			aim_query.exclude = excl
			var aim_hit: Dictionary = space_state.intersect_ray(aim_query)
			if not aim_hit.is_empty() and aim_hit.has("position"):
				aim_target = aim_hit["position"] as Vector3

	var to_target: Vector3 = aim_target - spawn_pos
	if to_target.length_squared() > 0.04 and to_target.normalized().dot(cam_fwd) > 0.15:
		_fly_dir = to_target.normalized()
	else:
		_fly_dir = cam_fwd

	_orient_along(_fly_dir)
	_phase = BombPhase.FLYING
	set_physics_process(true)
	set_process(true)

	SpellAudioManager.play_fire_cast(self, spawn_pos, 1.18, -2.0)


func _physics_process(delta: float) -> void:
	if _phase != BombPhase.FLYING:
		set_physics_process(false)
		return

	var step_dist: float = projectile_speed * delta
	var cur_pos: Vector3 = global_position
	var next_pos: Vector3 = cur_pos + _fly_dir * step_dist

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		# 1. Check environment ray (1 = sol/walls, 128 = trees)
		var env_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cur_pos, next_pos, 129)
		var env_hit: Dictionary = space_state.intersect_ray(env_query)
		var has_env_hit: bool = not env_hit.is_empty()
		var env_dist: float = cur_pos.distance_to(env_hit["position"] as Vector3) if has_env_hit else 9999.0

		# 2. Check enemy ray (8 = HitboxEnemie, 256 = enemie body)
		var mob_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cur_pos, next_pos, 264)
		mob_query.collide_with_areas = true
		mob_query.collide_with_bodies = true
		var mob_hit: Dictionary = space_state.intersect_ray(mob_query)
		if not mob_hit.is_empty():
			var hit_pos: Vector3 = mob_hit["position"] as Vector3
			if cur_pos.distance_to(hit_pos) <= env_dist + 0.05:
				var hit_mob: Node3D = _resolve_enemy_from_collider(mob_hit.get("collider") as Object)
				if hit_mob != null and not _is_mob_dead(hit_mob):
					_implant_into_monster(hit_mob, hit_pos)
					return

		# 3. Forgiving sphere overlap along step for thin skeletal limbs
		var shape_params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		shape_params.shape = _sweep_sphere
		shape_params.transform = Transform3D(Basis.IDENTITY, cur_pos.lerp(next_pos, 0.65))
		shape_params.collision_mask = 264
		shape_params.collide_with_areas = true
		shape_params.collide_with_bodies = true
		var overlaps: Array[Dictionary] = space_state.intersect_shape(shape_params, 6)
		for entry: Dictionary in overlaps:
			var cand_mob: Node3D = _resolve_enemy_from_collider(entry.get("collider") as Object)
			if cand_mob != null and not _is_mob_dead(cand_mob):
				_implant_into_monster(cand_mob, cur_pos.lerp(next_pos, 0.65))
				return

		if has_env_hit:
			var wall_pos: Vector3 = env_hit["position"] as Vector3
			global_position = wall_pos
			_fizzle_miss()
			return

	global_position = next_pos
	_last_seed_world_pos = next_pos
	_dist_travelled += step_dist
	if _dist_travelled >= max_flight_range:
		_fizzle_miss()


func _process(delta: float) -> void:
	if _phase == BombPhase.FLYING:
		_flight_time += delta
		var f_pulse: float = 0.92 + 0.16 * sin(_flight_time * 22.0)
		if _seed_shell_mi != null:
			_seed_shell_mi.scale = Vector3.ONE * f_pulse
		return

	if _phase == BombPhase.IMPLANTED:
		if _host_mob == null or not is_instance_valid(_host_mob) or _host_mob.is_queued_for_deletion() or _is_mob_dead(_host_mob):
			_detonate()
			return

		_fuse_elapsed += delta
		var charge: float = clampf(_fuse_elapsed / maxf(0.1, fuse_duration), 0.0, 1.0)
		var swell: float = lerpf(0.04, max_swell_amount, pow(charge, 0.82))

		_last_seed_world_pos = _host_mob.to_global(_local_hit_offset)
		global_position = _last_seed_world_pos

		# Accelerating heartbeat on the stuck seed
		var beat_freq: float = 12.0 + charge * 28.0
		var beat: float = 0.85 + 0.35 * absf(sin(_fuse_elapsed * beat_freq))
		var grow: float = lerpf(0.85, 1.45, charge) * beat
		if _seed_core_mi != null:
			_seed_core_mi.scale = Vector3.ONE * grow
		if _seed_shell_mi != null:
			_seed_shell_mi.scale = Vector3.ONE * (grow * 1.22)

		for smat: ShaderMaterial in _active_swell_mats:
			if smat != null:
				smat.set_shader_parameter("seed_world_pos", _last_seed_world_pos)
				smat.set_shader_parameter("swell_amount", swell)
				smat.set_shader_parameter("charge_ratio", charge)

		if _fuse_elapsed >= fuse_duration:
			_detonate()


func _exit_tree() -> void:
	_restore_host_materials()
	SpellAudioManager.stop_attached_loop(self)


func _implant_into_monster(host_mob: Node3D, raw_hit_pos: Vector3) -> void:
	_phase = BombPhase.IMPLANTED
	set_physics_process(false)
	_host_mob = host_mob
	_fuse_elapsed = 0.0

	# Clamp hit point near the monster's body surface so the spherical vertex swell always grabs the mesh cleanly
	var anchor: Vector3 = _get_mob_anchor_pos(host_mob)
	var offset_vec: Vector3 = raw_hit_pos - anchor
	var horiz: Vector2 = Vector2(offset_vec.x, offset_vec.z)
	var max_horiz: float = 0.65 if host_mob.is_in_group("Boss") else 0.38
	if horiz.length() > max_horiz:
		horiz = horiz.normalized() * max_horiz
	var clamped_y: float = clampf(raw_hit_pos.y, host_mob.global_position.y + 0.35, anchor.y + 0.85)
	var planted_world_pos: Vector3 = Vector3(anchor.x + horiz.x, clamped_y, anchor.z + horiz.y)

	_local_hit_offset = _host_mob.to_local(planted_world_pos)
	_last_seed_world_pos = planted_world_pos
	global_position = planted_world_pos

	_effective_swell_radius = base_swell_radius * (1.45 if host_mob.is_in_group("Boss") else 1.0)
	_apply_swell_shader_to_host(planted_world_pos)

	if _trail_particles != null:
		_trail_particles.amount_ratio = 0.45

	SpellAudioManager.play_fire_cast(self, planted_world_pos, 1.42, -2.4)
	SpellAudioManager.attach_fire_loop(self, -5.8, 9.5, 36.0)


func _apply_swell_shader_to_host(seed_pos: Vector3) -> void:
	if _host_mob == null or not is_instance_valid(_host_mob) or _swell_shader == null:
		return

	var mat_by_key: Dictionary = {}
	var found_nodes: Array[Node] = _host_mob.find_children("*", "MeshInstance3D", true, false)

	for node: Node in found_nodes:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi == null or not is_instance_valid(mi) or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		if _is_vfx_helper_mesh(mi):
			continue

		if not mi.has_meta(META_ORIG_CAPTURED):
			var init_override: Material = mi.material_override
			var init_surf0: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material_count() > 0 else null
			mi.set_meta(META_ORIG_OVERRIDE, init_override)
			mi.set_meta(META_ORIG_SURF0, init_surf0)
			mi.set_meta(META_ORIG_CAPTURED, true)
			mi.set_meta(META_REF_COUNT, 1)
		else:
			var cur_refs: int = int(mi.get_meta(META_REF_COUNT, 1))
			mi.set_meta(META_REF_COUNT, cur_refs + 1)

		var true_orig_override: Material = mi.get_meta(META_ORIG_OVERRIDE) as Material
		var true_orig_surf0: Material = mi.get_meta(META_ORIG_SURF0) as Material
		var src_mat: Material = true_orig_override
		if src_mat == null:
			src_mat = true_orig_surf0
		if src_mat == null:
			src_mat = mi.mesh.surface_get_material(0)

		var std_mat: BaseMaterial3D = src_mat as BaseMaterial3D
		var skin_tex: Texture2D = null
		var base_col: Color = Color.WHITE
		if std_mat != null:
			skin_tex = std_mat.albedo_texture
			base_col = std_mat.albedo_color

		var tex_id: int = skin_tex.get_instance_id() if skin_tex != null else 0
		var cache_key: String = str(tex_id) + "_" + base_col.to_html()
		var smat: ShaderMaterial = mat_by_key.get(cache_key) as ShaderMaterial
		if smat == null:
			smat = ShaderMaterial.new()
			smat.shader = _swell_shader
			smat.set_shader_parameter("has_skin_tex", skin_tex != null)
			if skin_tex != null:
				smat.set_shader_parameter("skin_tex", skin_tex)
			smat.set_shader_parameter("base_albedo", base_col)
			smat.set_shader_parameter("seed_world_pos", seed_pos)
			smat.set_shader_parameter("swell_radius", _effective_swell_radius)
			smat.set_shader_parameter("swell_amount", 0.04)
			smat.set_shader_parameter("charge_ratio", 0.0)
			mat_by_key[cache_key] = smat
			_active_swell_mats.append(smat)

		mi.material_override = smat
		_implanted_meshes.append(mi)

	_materials_applied = true


func _restore_host_materials() -> void:
	if not _materials_applied:
		return
	_materials_applied = false

	for mi: MeshInstance3D in _implanted_meshes:
		if mi == null or not is_instance_valid(mi):
			continue
		if mi.has_meta(META_ORIG_CAPTURED):
			var refs_left: int = int(mi.get_meta(META_REF_COUNT, 1)) - 1
			if refs_left <= 0:
				var orig_override: Material = mi.get_meta(META_ORIG_OVERRIDE) as Material
				var orig_surf0: Material = mi.get_meta(META_ORIG_SURF0) as Material
				mi.material_override = orig_override
				if mi.get_surface_override_material_count() > 0:
					mi.set_surface_override_material(0, orig_surf0)
				mi.remove_meta(META_ORIG_CAPTURED)
				mi.remove_meta(META_ORIG_OVERRIDE)
				mi.remove_meta(META_ORIG_SURF0)
				mi.remove_meta(META_REF_COUNT)
			else:
				mi.set_meta(META_REF_COUNT, refs_left)

	_implanted_meshes.clear()
	_active_swell_mats.clear()


func _detonate() -> void:
	if _phase == BombPhase.DETONATED:
		return
	_phase = BombPhase.DETONATED
	set_physics_process(false)
	set_process(false)

	var explode_pos: Vector3 = _last_seed_world_pos
	if _host_mob != null and is_instance_valid(_host_mob):
		explode_pos = _host_mob.to_global(_local_hit_offset)
	global_position = explode_pos

	_restore_host_materials()
	SpellAudioManager.stop_attached_loop(self)

	if _seed_core_mi != null:
		_seed_core_mi.visible = false
	if _seed_shell_mi != null:
		_seed_shell_mi.visible = false
	if _trail_particles != null:
		_trail_particles.emitting = false

	var blast_radius: float = scaling_component.final_impact_radius if scaling_component != null else 4.8
	SpellAudioManager.play_fire_impact(self, explode_pos, 0.88, 1.5)
	_spawn_explosion_vfx(explode_pos, blast_radius)

	if _is_auth and attack_component != null:
		_apply_explosion_damage(explode_pos, blast_radius)

	get_tree().create_timer(0.58).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _apply_explosion_damage(explode_pos: Vector3, blast_radius: float) -> void:
	attack_component.global_position = explode_pos
	var reach: float = blast_radius + 0.45
	var reach_sq: float = reach * reach
	var orig_fire_dmg: float = attack_component.damage_fire
	var orig_kb: float = attack_component.knockback_force
	var orig_effects: Array[StatusEffectApplication] = attack_component.status_effects_to_apply

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		if _is_mob_dead(mob):
			continue

		var is_host: bool = (mob == _host_mob)
		if not is_host:
			var anchor: Vector3 = _get_mob_anchor_pos(mob)
			if explode_pos.distance_squared_to(anchor) > reach_sq:
				continue

		var hb: HitboxComponent = _resolve_mob_hitbox(mob)
		if hb == null:
			continue

		# 1.0x AoE fire hit + Burn 4.0s + Knockback
		attack_component.damage_fire = orig_fire_dmg
		attack_component.knockback_force = orig_kb
		attack_component.status_effects_to_apply = orig_effects
		hb.receive_hit(attack_component)

		# +55% bonus fire damage on the implanted host monster (1.55x total, heavy hit without one-shotting bosses)
		if is_host and not _is_mob_dead(mob):
			var empty_effects: Array[StatusEffectApplication] = []
			attack_component.damage_fire = orig_fire_dmg * host_bonus_damage_ratio
			attack_component.knockback_force = 0.0
			attack_component.status_effects_to_apply = empty_effects
			hb.receive_hit(attack_component)

	attack_component.damage_fire = orig_fire_dmg
	attack_component.knockback_force = orig_kb
	attack_component.status_effects_to_apply = orig_effects


func _spawn_explosion_vfx(explode_pos: Vector3, blast_radius: float) -> void:
	var sphere_mat: StandardMaterial3D = StandardMaterial3D.new()
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere_mat.albedo_color = Color(2.8, 1.25, 0.25, 0.72)

	var wave_sphere: MeshInstance3D = MeshInstance3D.new()
	wave_sphere.mesh = _blast_sphere_mesh
	wave_sphere.material_override = sphere_mat
	wave_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave_sphere.scale = Vector3.ONE * 0.25
	add_child(wave_sphere)

	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.albedo_color = Color(3.2, 1.55, 0.35, 0.85)

	var wave_ring: MeshInstance3D = MeshInstance3D.new()
	wave_ring.mesh = _blast_ring_mesh
	wave_ring.material_override = ring_mat
	wave_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave_ring.scale = Vector3(0.3, 0.16, 0.3)
	add_child(wave_ring)

	var burst: GPUParticles3D = GPUParticles3D.new()
	burst.material_override = _burst_mat
	burst.process_material = _burst_proc
	burst.draw_pass_1 = _burst_quad
	burst.amount = 26
	burst.lifetime = 0.48
	burst.one_shot = true
	burst.explosiveness = 0.94
	burst.fixed_fps = 30
	burst.visibility_range_end = 56.0
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	burst.global_position = explode_pos
	burst.emitting = true

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave_sphere, "scale", Vector3.ONE * (blast_radius * 0.82), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sphere_mat, "albedo_color", Color(1.4, 0.22, 0.02, 0.0), 0.28)
	tw.tween_property(wave_ring, "scale", Vector3(blast_radius * 0.98, 0.22, blast_radius * 0.98), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color", Color(1.6, 0.30, 0.03, 0.0), 0.32)


func _fizzle_miss() -> void:
	if _phase != BombPhase.FLYING:
		return
	_phase = BombPhase.DETONATED
	set_physics_process(false)
	set_process(false)
	SpellAudioManager.play_fire_impact(self, global_position, 1.38, -4.5)
	if _seed_core_mi != null:
		_seed_core_mi.visible = false
	if _seed_shell_mi != null:
		_seed_shell_mi.visible = false
	if _trail_particles != null:
		_trail_particles.emitting = false
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _orient_along(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		var up_vec: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		look_at(global_position + dir, up_vec)


static func _resolve_enemy_from_collider(col: Object) -> Node3D:
	var n: Node = col as Node
	while n != null:
		if n.is_in_group("Enemie"):
			return n as Node3D
		n = n.get_parent()
	var hb: HitboxComponent = col as HitboxComponent
	if hb != null and hb.owner != null and hb.owner.is_in_group("Enemie"):
		return hb.owner as Node3D
	return null


static func _resolve_mob_hitbox(mob: Node3D) -> HitboxComponent:
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


static func _is_mob_dead(mob: Node3D) -> bool:
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
		return true
	if mob.get("is_dead") == true:
		return true
	var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	return false


static func _is_vfx_helper_mesh(mi: MeshInstance3D) -> bool:
	var p: Node = mi.get_parent()
	while p != null:
		if p is StatusEffectComponent or p is CombatFeedbackComponent or p is HitboxComponent:
			return true
		if p.name == "blood_explosion_vfx":
			return true
		if p.is_in_group("Enemie"):
			break
		p = p.get_parent()
	return false


static func _get_mob_anchor_pos(mob: Node3D) -> Vector3:
	var cs: CollisionShape3D = mob.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		if cs.position.y < 0.05:
			return cs.global_position
		return mob.global_position + Vector3(cs.position.x, clampf(cs.position.y, 0.4, 1.5), cs.position.z)
	return mob.global_position + Vector3(0.0, 1.0, 0.0)
