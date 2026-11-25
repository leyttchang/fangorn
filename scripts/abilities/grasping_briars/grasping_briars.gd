extends Node3D

const POOL_SIZE: int = 20
const BURST_POOL_SIZE: int = 6
const VINE_VARIANTS_COUNT: int = 3
const VINE_CURVE_STEPS: int = 18

static var _master_vine_variants: Array[Dictionary] = []
static var _tendril_vine_variants: Array[Dictionary] = []
static var _crown_root_variants: Array[Dictionary] = []
static var _base_dark_bark_mat: ShaderMaterial = null
static var _base_moss_bark_mat: ShaderMaterial = null
static var _crown_bark_mat: ShaderMaterial = null

static var _spark_quad_mesh: QuadMesh = null
static var _spark_mat: StandardMaterial3D = null
static var _head_spark_proc: ParticleProcessMaterial = null
static var _erupt_soil_mat: StandardMaterial3D = null
static var _erupt_soil_proc: ParticleProcessMaterial = null
static var _query_sphere_cache: Dictionary = {}

@export var steer_speed: float = 13.5
@export var max_carry_speed: float = 15.5
@export var max_carry_distance: float = 5.5
@export var max_carry_duration: float = 1.35
@export var release_immunity_ms: int = 1400
@export var erupt_spacing: float = 0.72
@export var base_tick_interval: float = 0.34

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

class BriarSegment:
	var root_node: Node3D = null
	var primary_mat: ShaderMaterial = null
	var secondary_mat: ShaderMaterial = null
	var active: bool = false
	var age: float = 0.0
	var max_age: float = 1.12
	var target_scale: float = 1.0

var _segments: Array[BriarSegment] = []
var _pool_cursor: int = 0
var _soil_bursts: Array[GPUParticles3D] = []
var _burst_cursor: int = 0
var _head_holder: Node3D = null
var _head_sparks: GPUParticles3D = null

var _caster: Node3D = null
var _head_pos: Vector3 = Vector3.ZERO
var _target_ground_pos: Vector3 = Vector3.ZERO
var _current_dir: Vector3 = Vector3.FORWARD
var _is_channeling: bool = false
var _is_auth: bool = true
var _dist_since_erupt: float = 0.0
var _time_since_erupt: float = 0.0
var _damage_scan_accum: float = 0.0
var _effective_tick_interval: float = 0.34
var _effective_steer_speed: float = 13.5
var _erupt_radius: float = 2.45
var _max_range: float = 24.0
var _audio_cooldown: float = 0.0
var _enemy_next_hit_msec: Dictionary = {}
var _captured_mobs: Dictionary = {}
var _release_cooldown_until_ms: Dictionary = {}


static func _sample_master_arch_curve(variant_idx: int, t: float) -> Vector3:
	var z: float = lerpf(-1.55, 1.50, t)
	# Légère asymétrie organique vers l'avant (comme une vague de racines qui déferle)
	var skewed_t: float = pow(clampf(t, 0.0, 1.0), 0.90)
	var arch_sin: float = sin(skewed_t * PI)
	var peak_h: float = 1.46
	if variant_idx == 1:
		peak_h = 1.62
	elif variant_idx == 2:
		peak_h = 1.30

	var crest_env: float = pow(maxf(0.0, arch_sin), 0.82)
	var gnarl_y: float = 0.08 * sin(t * TAU * 1.5 + float(variant_idx) * 1.7) * arch_sin
	var y: float = -0.38 + (peak_h + 0.38) * crest_env + gnarl_y

	var side_env: float = pow(maxf(0.0, arch_sin), 0.55)
	var x: float = 0.0
	if variant_idx == 0:
		x = 0.32 * sin(t * TAU + 0.30) * side_env
	elif variant_idx == 1:
		x = -0.34 * sin(t * TAU - 0.25) * side_env
	else:
		x = 0.26 * sin(t * PI * 3.0 - PI * 0.45) * side_env

	return Vector3(x, y, z)


static func _sample_tendril_arch_curve(variant_idx: int, t: float) -> Vector3:
	var z: float = lerpf(-1.42, 1.42, t)
	var arch_sin: float = sin(t * PI)
	var peak_h: float = 1.05
	if variant_idx == 1:
		peak_h = 1.28
	elif variant_idx == 2:
		peak_h = 0.92

	var crest_env: float = pow(maxf(0.0, arch_sin), 0.78)
	var wave_y: float = 0.11 * cos(t * TAU * 2.0 + float(variant_idx) * 2.1) * arch_sin
	var y: float = -0.36 + (peak_h + 0.36) * crest_env + wave_y

	var twist_sign: float = -1.0 if (variant_idx % 2 == 1) else 1.0
	var x: float = twist_sign * 0.44 * sin(t * TAU * 1.25 + float(variant_idx) * 0.9) * pow(maxf(0.0, arch_sin), 0.50)
	return Vector3(x, y, z)


static func _ensure_shared_meshes() -> void:
	if _master_vine_variants.is_empty():
		for v_idx: int in range(VINE_VARIANTS_COUNT):
			var pts: PackedVector3Array = PackedVector3Array()
			pts.resize(VINE_CURVE_STEPS)
			for s: int in range(VINE_CURVE_STEPS):
				var t: float = float(s) / float(VINE_CURVE_STEPS - 1)
				pts[s] = _sample_master_arch_curve(v_idx, t)
			var built: Dictionary = ProceduralForestMeshes.build_centered_root_tube(
				pts,
				0.26,
				9,
				0.042,
				23 + v_idx * 17
			)
			_master_vine_variants.append(built)

	if _tendril_vine_variants.is_empty():
		for v_idx: int in range(VINE_VARIANTS_COUNT):
			var pts_t: PackedVector3Array = PackedVector3Array()
			pts_t.resize(VINE_CURVE_STEPS)
			for s: int in range(VINE_CURVE_STEPS):
				var t: float = float(s) / float(VINE_CURVE_STEPS - 1)
				pts_t[s] = _sample_tendril_arch_curve(v_idx, t)
			var built_t: Dictionary = ProceduralForestMeshes.build_centered_root_tube(
				pts_t,
				0.15,
				7,
				0.032,
				71 + v_idx * 19
			)
			_tendril_vine_variants.append(built_t)

	if _crown_root_variants.is_empty():
		for c_idx: int in range(4):
			var c_pts: PackedVector3Array = PackedVector3Array()
			c_pts.resize(10)
			var ang: float = (TAU / 4.0) * float(c_idx) + 0.38
			var dir_xz: Vector2 = Vector2(cos(ang), sin(ang))
			var perp_xz: Vector2 = Vector2(-dir_xz.y, dir_xz.x)
			for s: int in range(10):
				var u: float = float(s) / 9.0
				var r_out: float = lerpf(0.18, 1.05, u)
				var sway: float = sin(u * PI * 1.5 + float(c_idx)) * 0.16
				var p_xz: Vector2 = dir_xz * r_out + perp_xz * sway
				var py: float = -0.16 + 0.36 * sin(u * PI)
				c_pts[s] = Vector3(p_xz.x, py, p_xz.y)
			var built_c: Dictionary = ProceduralForestMeshes.build_centered_root_tube(
				c_pts,
				0.10,
				6,
				0.020,
				131 + c_idx * 11
			)
			_crown_root_variants.append(built_c)

	# Couleurs d'écorce naturelles de Fangorn (bois sombre + écorce moussue)
	if _base_dark_bark_mat == null:
		_base_dark_bark_mat = ProceduralForestMeshes.get_base_root_material(
			Color(0.46, 0.38, 0.28, 1.0),
			0.14,
			2.5
		)
		_base_dark_bark_mat.set_shader_parameter("fin", 0.0)
		_base_dark_bark_mat.set_shader_parameter("debut", 0.0)

	if _base_moss_bark_mat == null:
		_base_moss_bark_mat = ProceduralForestMeshes.get_base_root_material(
			Color(0.36, 0.44, 0.24, 1.0),
			0.13,
			2.2
		)
		_base_moss_bark_mat.set_shader_parameter("fin", 0.0)
		_base_moss_bark_mat.set_shader_parameter("debut", 0.0)

	if _crown_bark_mat == null:
		_crown_bark_mat = ProceduralForestMeshes.get_base_root_material(
			Color(0.42, 0.39, 0.26, 1.0),
			0.11,
			1.6
		)
		_crown_bark_mat.set_shader_parameter("fin", 0.0)
		_crown_bark_mat.set_shader_parameter("debut", 1.0)

	if _spark_quad_mesh == null:
		_spark_quad_mesh = QuadMesh.new()
		_spark_quad_mesh.size = Vector2(0.11, 0.11)

	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.vertex_color_use_as_albedo = true
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mat.billboard_keep_scale = true

	if _head_spark_proc == null:
		var hpm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		hpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		hpm.emission_ring_axis = Vector3.UP
		hpm.emission_ring_radius = 0.85
		hpm.emission_ring_inner_radius = 0.20
		hpm.emission_ring_height = 0.12
		hpm.direction = Vector3.UP
		hpm.spread = 28.0
		hpm.initial_velocity_min = 0.9
		hpm.initial_velocity_max = 2.2
		hpm.gravity = Vector3(0.0, -1.8, 0.0)
		hpm.scale_min = 0.45
		hpm.scale_max = 0.95

		var h_grad: Gradient = Gradient.new()
		h_grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		h_grad.colors = PackedColorArray([
			Color(1.8, 0.65, 3.0, 0.0),
			Color(2.1, 0.80, 3.4, 0.85),
			Color(0.8, 1.3, 0.6, 0.0)
		])
		var h_ramp: GradientTexture1D = GradientTexture1D.new()
		h_ramp.gradient = h_grad
		hpm.color_ramp = h_ramp
		_head_spark_proc = hpm

	if _erupt_soil_mat == null:
		_erupt_soil_mat = StandardMaterial3D.new()
		_erupt_soil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_erupt_soil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_erupt_soil_mat.vertex_color_use_as_albedo = true
		_erupt_soil_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_erupt_soil_mat.billboard_keep_scale = true

	if _erupt_soil_proc == null:
		var spm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		spm.emission_ring_axis = Vector3.UP
		spm.emission_ring_radius = 0.72
		spm.emission_ring_inner_radius = 0.15
		spm.emission_ring_height = 0.08
		spm.direction = Vector3.UP
		spm.spread = 36.0
		spm.initial_velocity_min = 2.4
		spm.initial_velocity_max = 4.6
		spm.gravity = Vector3(0.0, -9.2, 0.0)
		spm.scale_min = 0.65
		spm.scale_max = 1.35

		var s_grad: Gradient = Gradient.new()
		s_grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		s_grad.colors = PackedColorArray([
			Color(0.45, 0.36, 0.24, 0.90),
			Color(0.38, 0.48, 0.25, 0.75),
			Color(0.28, 0.22, 0.16, 0.0)
		])
		var s_ramp: GradientTexture1D = GradientTexture1D.new()
		s_ramp.gradient = s_grad
		spm.color_ramp = s_ramp
		_erupt_soil_proc = spm


static func _get_query_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(8, int(roundf(rad * 20.0)))
	if _query_sphere_cache.has(key):
		return _query_sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 20.0
	_query_sphere_cache[key] = sph
	return sph


static func _find_mob_hitbox(mob: Node3D) -> HitboxComponent:
	if mob == null:
		return null
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


func _ready() -> void:
	_ensure_shared_meshes()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	# Couronne organique de petites racines rampantes + fines étincelles arcaniques en tête de sillon
	_head_holder = Node3D.new()
	_head_holder.name = "BriarHeadCrown"
	_head_holder.visible = false
	add_child(_head_holder)

	for c_idx: int in range(_crown_root_variants.size()):
		var c_data: Dictionary = _crown_root_variants[c_idx]
		var c_mi: MeshInstance3D = MeshInstance3D.new()
		c_mi.mesh = c_data.get("mesh") as ArrayMesh
		c_mi.position = c_data.get("center", Vector3.ZERO) as Vector3
		c_mi.material_override = _crown_bark_mat
		c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_holder.add_child(c_mi)

	_head_sparks = GPUParticles3D.new()
	_head_sparks.material_override = _spark_mat
	_head_sparks.process_material = _head_spark_proc
	_head_sparks.draw_pass_1 = _spark_quad_mesh
	_head_sparks.amount = 18
	_head_sparks.lifetime = 0.52
	_head_sparks.fixed_fps = 30
	_head_sparks.emitting = false
	_head_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head_holder.add_child(_head_sparks)

	# Pool de jets de terre/feuilles réutilisables aux éruptions
	for b_idx: int in range(BURST_POOL_SIZE):
		var burst: GPUParticles3D = GPUParticles3D.new()
		burst.name = "SoilBurst_" + str(b_idx)
		burst.material_override = _erupt_soil_mat
		burst.process_material = _erupt_soil_proc
		burst.draw_pass_1 = _spark_quad_mesh
		burst.amount = 12
		burst.lifetime = 0.45
		burst.one_shot = true
		burst.explosiveness = 0.92
		burst.fixed_fps = 30
		burst.emitting = false
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		_soil_bursts.append(burst)

	# Pool de 20 enchevêtrements denses de 3 lianes organiques entrelacées
	for i: int in range(POOL_SIZE):
		var holder: Node3D = Node3D.new()
		holder.name = "BriarSegment_" + str(i)
		holder.visible = false

		var prim_mat: ShaderMaterial = _base_dark_bark_mat.duplicate() as ShaderMaterial
		prim_mat.set_shader_parameter("fin", 0.0)
		prim_mat.set_shader_parameter("debut", 0.0)

		var sec_mat: ShaderMaterial = _base_moss_bark_mat.duplicate() as ShaderMaterial
		sec_mat.set_shader_parameter("fin", 0.0)
		sec_mat.set_shader_parameter("debut", 0.0)

		var m_idx: int = i % VINE_VARIANTS_COUNT
		var t_idx_a: int = (i + 1) % VINE_VARIANTS_COUNT
		var t_idx_b: int = (i + 2) % VINE_VARIANTS_COUNT

		var master_data: Dictionary = _master_vine_variants[m_idx]
		var tendril_a_data: Dictionary = _tendril_vine_variants[t_idx_a]
		var tendril_b_data: Dictionary = _tendril_vine_variants[t_idx_b]

		# 1) Grosse liane maîtresse noueuse (base_radius = 0.26)
		var master_mi: MeshInstance3D = MeshInstance3D.new()
		master_mi.mesh = master_data.get("mesh") as ArrayMesh
		master_mi.position = master_data.get("center", Vector3.ZERO) as Vector3
		master_mi.material_override = prim_mat
		master_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(master_mi)

		# 2) Liane secondaire moussue croisée (+0.32 rad)
		var tendril_a_mi: MeshInstance3D = MeshInstance3D.new()
		tendril_a_mi.mesh = tendril_a_data.get("mesh") as ArrayMesh
		var center_a: Vector3 = tendril_a_data.get("center", Vector3.ZERO) as Vector3
		var basis_a: Basis = Basis(Vector3.UP, 0.32) * Basis(Vector3.FORWARD, 0.06)
		tendril_a_mi.transform = Transform3D(basis_a, basis_a * center_a + Vector3(-0.22, 0.0, -0.06))
		tendril_a_mi.material_override = sec_mat
		tendril_a_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(tendril_a_mi)

		# 3) Liane secondaire sombre croisée (-0.32 rad)
		var tendril_b_mi: MeshInstance3D = MeshInstance3D.new()
		tendril_b_mi.mesh = tendril_b_data.get("mesh") as ArrayMesh
		var center_b: Vector3 = tendril_b_data.get("center", Vector3.ZERO) as Vector3
		var basis_b: Basis = Basis(Vector3.UP, -0.32) * Basis(Vector3.FORWARD, -0.06)
		tendril_b_mi.transform = Transform3D(basis_b, basis_b * center_b + Vector3(0.22, -0.04, 0.06))
		tendril_b_mi.material_override = prim_mat
		tendril_b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(tendril_b_mi)

		add_child(holder)

		var seg: BriarSegment = BriarSegment.new()
		seg.root_node = holder
		seg.primary_mat = prim_mat
		seg.secondary_mat = sec_mat
		_segments.append(seg)


func start_channel(caster: Node3D, aim_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	var is_remote: bool = bool(aim_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())

	var ab_data: AbilityData = aim_data.get("ability_data") as AbilityData
	if ab_data != null and ab_data.max_range > 0.0:
		_max_range = ab_data.max_range

	if attack_component != null:
		attack_component.on_execute(_caster, aim_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, aim_data)
		_erupt_radius = scaling_component.final_impact_radius

	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick_interval = maxf(0.10, base_tick_interval / cast_spd)
	_effective_steer_speed = steer_speed * sqrt(cast_spd)

	var fwd: Vector3 = -_caster.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	_current_dir = fwd

	_head_pos = _snap_to_ground(_caster.global_position + fwd * 1.6, _caster.global_position.y)
	_target_ground_pos = _resolve_ground_target(aim_data)
	var init_to: Vector3 = Vector3(_target_ground_pos.x - _head_pos.x, 0.0, _target_ground_pos.z - _head_pos.z)
	if init_to.length_squared() > 0.01:
		_current_dir = init_to.normalized()

	_captured_mobs.clear()
	_release_cooldown_until_ms.clear()

	_is_channeling = true
	if _head_holder != null:
		_head_holder.visible = true
		_head_holder.global_position = _head_pos
		var aoe_mult: float = scaling_component.final_aoe_multiplier if scaling_component != null else 1.0
		_head_holder.scale = Vector3.ONE * aoe_mult
	if _head_sparks != null:
		_head_sparks.emitting = true

	_erupt_at(_head_pos, _current_dir)


func update_channel(caster: Node3D, _delta: float, aim_data: Dictionary) -> void:
	_caster = caster
	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick_interval = maxf(0.10, base_tick_interval / cast_spd)
	_effective_steer_speed = steer_speed * sqrt(cast_spd)
	_target_ground_pos = _resolve_ground_target(aim_data)


func update_remote_aim(aim_point: Vector3, aim_dir: Vector3) -> void:
	var fake_data: Dictionary = {
		"aim_point": aim_point,
		"aim_dir": aim_dir,
		"has_hit": true
	}
	_target_ground_pos = _resolve_ground_target(fake_data)


func stop_channel() -> void:
	_is_channeling = false
	_captured_mobs.clear()
	if _head_holder != null:
		_head_holder.visible = false
	if _head_sparks != null:
		_head_sparks.emitting = false


func _physics_process(delta: float) -> void:
	if not _is_channeling:
		return
	if _caster == null or not is_instance_valid(_caster):
		stop_channel()
		return

	_step_head(delta)

	if _is_auth:
		_capture_and_carry_enemies(delta)
		_damage_scan_accum += delta
		if _damage_scan_accum >= 0.09:
			_damage_scan_accum = 0.0
			_damage_enemies_at(_head_pos)


func _process(delta: float) -> void:
	if _audio_cooldown > 0.0:
		_audio_cooldown -= delta

	if _is_channeling and _head_holder != null:
		_head_holder.global_position = _head_pos
		_head_holder.rotate_y(delta * 2.4)

	var any_active: bool = false
	for seg: BriarSegment in _segments:
		if not seg.active:
			continue
		any_active = true
		seg.age += delta
		var u_age: float = seg.age / seg.max_age
		if u_age >= 1.0:
			seg.active = false
			seg.root_node.visible = false
			seg.primary_mat.set_shader_parameter("fin", 0.0)
			seg.primary_mat.set_shader_parameter("debut", 0.0)
			seg.secondary_mat.set_shader_parameter("fin", 0.0)
			seg.secondary_mat.set_shader_parameter("debut", 0.0)
			continue

		# 1) Liane maîtresse : jaillit du sol à l'arrière, s'élève en arche vers l'avant, puis replonge sous terre
		var grow_p: float = clampf(u_age / 0.38, 0.0, 1.0)
		var eased_grow_p: float = 1.0 - pow(1.0 - grow_p, 2.5)
		var debut_p: float = lerpf(0.03, 1.0, eased_grow_p)

		var dive_p: float = clampf((u_age - 0.44) / 0.56, 0.0, 1.0)
		var eased_dive_p: float = dive_p * dive_p * (3.0 - 2.0 * dive_p)
		var fin_p: float = lerpf(0.0, 1.0, eased_dive_p)

		seg.primary_mat.set_shader_parameter("debut", debut_p)
		seg.primary_mat.set_shader_parameter("fin", fin_p)

		# 2) Lianes vrillées secondaires avec léger déphasage organique
		var u_sec: float = clampf((u_age - 0.05) / 0.95, 0.0, 1.0)
		var grow_s: float = clampf(u_sec / 0.38, 0.0, 1.0)
		var eased_grow_s: float = 1.0 - pow(1.0 - grow_s, 2.4)
		var debut_s: float = lerpf(0.02, 1.0, eased_grow_s)

		var dive_s: float = clampf((u_sec - 0.42) / 0.58, 0.0, 1.0)
		var eased_dive_s: float = dive_s * dive_s * (3.0 - 2.0 * dive_s)
		var fin_s: float = lerpf(0.0, 1.0, eased_dive_s)

		seg.secondary_mat.set_shader_parameter("debut", debut_s)
		seg.secondary_mat.set_shader_parameter("fin", fin_s)

	if not _is_channeling and not any_active:
		queue_free()


func _step_head(delta: float) -> void:
	var to_target: Vector3 = _target_ground_pos - _head_pos
	var flat_to: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var flat_len: float = flat_to.length()
	var moved_dist: float = 0.0

	if flat_len > 0.06:
		var desired_dir: Vector3 = flat_to / flat_len
		_current_dir = desired_dir
		var step: float = minf(flat_len, _effective_steer_speed * delta)
		var next_flat: Vector3 = _head_pos + desired_dir * step

		var from_caster: Vector3 = Vector3(
			next_flat.x - _caster.global_position.x,
			0.0,
			next_flat.z - _caster.global_position.z
		)
		if from_caster.length() > _max_range:
			from_caster = from_caster.normalized() * _max_range
			next_flat.x = _caster.global_position.x + from_caster.x
			next_flat.z = _caster.global_position.z + from_caster.z

		var snapped: Vector3 = _snap_to_ground(next_flat, _head_pos.y)
		var actual_flat: Vector3 = Vector3(snapped.x - _head_pos.x, 0.0, snapped.z - _head_pos.z)
		moved_dist = actual_flat.length()
		if moved_dist > 0.002:
			_current_dir = actual_flat / moved_dist
		_head_pos = snapped

	_dist_since_erupt += moved_dist
	_time_since_erupt += delta

	if _dist_since_erupt >= erupt_spacing or _time_since_erupt >= _effective_tick_interval:
		_dist_since_erupt = 0.0
		_time_since_erupt = 0.0
		_erupt_at(_head_pos, _current_dir)


func _capture_and_carry_enemies(delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var now_ms: int = Time.get_ticks_msec()
	var capture_radius: float = _erupt_radius * 1.1

	# 1) Capture des nouveaux monstres sur le passage de la tête de ronces
	for mob_node: Node in tree.get_nodes_in_group("Enemie"):
		var mob: Node3D = mob_node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.get("is_dead") == true:
			continue
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and (hc.is_intangible or hc.current_health <= 0.0):
			continue

		var mob_id: int = mob.get_instance_id()
		if _captured_mobs.has(mob_id):
			continue
		var immune_until: int = int(_release_cooldown_until_ms.get(mob_id, 0))
		if now_ms < immune_until:
			continue

		var rel_flat: Vector3 = Vector3(
			mob.global_position.x - _head_pos.x,
			0.0,
			mob.global_position.z - _head_pos.z
		)
		var dist_flat: float = rel_flat.length()
		if dist_flat <= capture_radius and absf(mob.global_position.y - _head_pos.y) <= 3.2:
			var clamped_side: Vector3 = rel_flat
			if dist_flat > 0.85:
				clamped_side = (rel_flat / dist_flat) * 0.85
			_captured_mobs[mob_id] = {
				"mob": mob,
				"carried_dist": 0.0,
				"side_offset": clamped_side,
				"age": 0.0
			}
			_try_hit_mob_direct(mob, now_ms)

	if _captured_mobs.is_empty():
		return

	# 2) Entraînement des monstres capturés à pleine vitesse avec la tête sur ~5.5m avant relâchement !
	var speed_scale: float = maxf(1.0, _effective_steer_speed / maxf(1.0, steer_speed))
	var step_cap: float = max_carry_speed * speed_scale * delta
	var captured_ids: Array = _captured_mobs.keys()

	for id_var: Variant in captured_ids:
		var mob_id_c: int = int(id_var)
		if not _captured_mobs.has(mob_id_c):
			continue
		var entry: Dictionary = _captured_mobs[mob_id_c] as Dictionary
		var c_mob: Node3D = entry.get("mob") as Node3D
		if c_mob == null or not is_instance_valid(c_mob) or c_mob.get("is_dead") == true:
			_captured_mobs.erase(mob_id_c)
			continue

		var c_hc: HealthComponent = c_mob.get_node_or_null("HealthComponent") as HealthComponent
		if c_hc != null and (c_hc.is_intangible or c_hc.current_health <= 0.0):
			_captured_mobs.erase(mob_id_c)
			continue

		var kc: KnockbackComponent = c_mob.get_node_or_null("knockback_componant") as KnockbackComponent
		if kc == null:
			kc = c_mob.get_node_or_null("KnockbackComponent") as KnockbackComponent
		if kc == null:
			_captured_mobs.erase(mob_id_c)
			continue

		var side_off: Vector3 = entry.get("side_offset", Vector3.ZERO) as Vector3
		var target_slot: Vector3 = _head_pos + _current_dir * 0.35 + side_off * 0.45
		var to_slot_xz: Vector3 = Vector3(
			target_slot.x - c_mob.global_position.x,
			0.0,
			target_slot.z - c_mob.global_position.z
		)
		var dist_to_slot: float = to_slot_xz.length()
		var carry_step: Vector3 = Vector3.ZERO
		if dist_to_slot > 0.02:
			var move_len: float = minf(dist_to_slot, step_cap)
			carry_step = (to_slot_xz / dist_to_slot) * move_len
			kc.apply_pull_displacement(carry_step)

		var new_carried: float = float(entry.get("carried_dist", 0.0)) + carry_step.length()
		var new_age: float = float(entry.get("age", 0.0)) + delta
		entry["carried_dist"] = new_carried
		entry["age"] = new_age

		# Garde le root et le tick actifs tant qu'il est emporté dans les ronces
		_try_hit_mob_direct(c_mob, now_ms)

		if new_carried >= max_carry_distance or new_age >= max_carry_duration:
			_captured_mobs.erase(mob_id_c)
			_release_cooldown_until_ms[mob_id_c] = now_ms + release_immunity_ms


func _try_hit_mob_direct(mob: Node3D, now_ms: int) -> void:
	if attack_component == null or mob == null:
		return
	var eid: int = mob.get_instance_id()
	var next_ok_ms: int = int(_enemy_next_hit_msec.get(eid, 0))
	if now_ms < next_ok_ms:
		return
	var hb: HitboxComponent = _find_mob_hitbox(mob)
	if hb == null:
		return
	var cooldown_ms: int = maxi(120, int(roundf(_effective_tick_interval * 1000.0)))
	_enemy_next_hit_msec[eid] = now_ms + cooldown_ms
	attack_component.global_position = _head_pos
	hb.receive_hit(attack_component)


func _erupt_at(pos: Vector3, dir: Vector3) -> void:
	if _segments.is_empty():
		return
	var seg: BriarSegment = _segments[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _segments.size()

	seg.active = true
	seg.age = 0.0
	seg.max_age = 1.12
	var aoe_mult: float = scaling_component.final_aoe_multiplier if scaling_component != null else 1.0
	seg.target_scale = randf_range(0.92, 1.15) * aoe_mult

	var yaw: float = atan2(dir.x, dir.z) + randf_range(-0.22, 0.22)
	seg.root_node.visible = true
	seg.root_node.global_position = pos
	seg.root_node.rotation = Vector3(0.0, yaw, 0.0)
	seg.root_node.scale = Vector3.ONE * seg.target_scale

	seg.primary_mat.set_shader_parameter("fin", 0.0)
	seg.primary_mat.set_shader_parameter("debut", 0.04)
	seg.secondary_mat.set_shader_parameter("fin", 0.0)
	seg.secondary_mat.set_shader_parameter("debut", 0.02)

	if not _soil_bursts.is_empty():
		var burst: GPUParticles3D = _soil_bursts[_burst_cursor]
		_burst_cursor = (_burst_cursor + 1) % _soil_bursts.size()
		burst.global_position = pos + Vector3(0.0, 0.08, 0.0)
		burst.restart()
		burst.emitting = true

	if _audio_cooldown <= 0.0:
		_audio_cooldown = 0.28
		SpellAudioManager.play_ice_windup(self, pos, 0.64, -4.8)

	if _is_auth and attack_component != null:
		_damage_enemies_at(pos)


func _damage_enemies_at(pos: Vector3) -> void:
	if attack_component == null:
		return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return

	var now_ms: int = Time.get_ticks_msec()
	var cooldown_ms: int = maxi(120, int(roundf(_effective_tick_interval * 1000.0)))
	var hit_entities_this_pulse: Dictionary = {}
	attack_component.global_position = pos

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _get_query_sphere(_erupt_radius)
	params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.85, 0.0))
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var hits: Array[Dictionary] = space_state.intersect_shape(params, 20)
	for entry: Dictionary in hits:
		var col_obj: Object = entry.get("collider") as Object
		var hb: HitboxComponent = col_obj as HitboxComponent
		if hb == null:
			continue
		var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
		if entity == null or entity == _caster or entity.is_in_group("Player"):
			continue
		var eid: int = entity.get_instance_id()
		if hit_entities_this_pulse.has(eid):
			continue
		var next_ok_ms: int = int(_enemy_next_hit_msec.get(eid, 0))
		if now_ms < next_ok_ms:
			continue
		hit_entities_this_pulse[eid] = true
		_enemy_next_hit_msec[eid] = now_ms + cooldown_ms
		hb.receive_hit(attack_component)

	var tree: SceneTree = get_tree()
	if tree != null:
		for mob_node: Node in tree.get_nodes_in_group("Enemie"):
			var mob: Node3D = mob_node as Node3D
			if mob == null or not is_instance_valid(mob) or mob.get("is_dead") == true:
				continue
			var eid_m: int = mob.get_instance_id()
			if hit_entities_this_pulse.has(eid_m):
				continue
			var next_ok_m: int = int(_enemy_next_hit_msec.get(eid_m, 0))
			if now_ms < next_ok_m:
				continue
			var d_flat: float = Vector2(mob.global_position.x - pos.x, mob.global_position.z - pos.z).length()
			if d_flat <= _erupt_radius and absf(mob.global_position.y - pos.y) <= 2.8:
				var mob_hb: HitboxComponent = _find_mob_hitbox(mob)
				if mob_hb != null:
					hit_entities_this_pulse[eid_m] = true
					_enemy_next_hit_msec[eid_m] = now_ms + cooldown_ms
					mob_hb.receive_hit(attack_component)


func _resolve_ground_target(aim_data: Dictionary) -> Vector3:
	var has_hit: bool = bool(aim_data.get("has_hit", false))
	if has_hit and aim_data.has("aim_point"):
		var pt: Vector3 = aim_data["aim_point"] as Vector3
		return _snap_to_ground(pt, _caster.global_position.y if _caster != null else pt.y)

	var origin: Vector3 = aim_data.get("aim_origin", _head_pos + Vector3(0.0, 1.4, 0.0)) as Vector3
	var dir: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
	var ground_y: float = _caster.global_position.y if _caster != null else 0.0
	var proj: Vector3 = origin + dir * 16.0
	if dir.y < -0.04:
		var t: float = clampf((ground_y - origin.y) / dir.y, 1.0, _max_range)
		proj = origin + dir * t
	else:
		var flat_d: Vector3 = Vector3(dir.x, 0.0, dir.z)
		if flat_d.length_squared() > 0.001:
			proj = (_caster.global_position if _caster != null else origin) + flat_d.normalized() * 18.0
	return _snap_to_ground(proj, ground_y)


func _snap_to_ground(pos: Vector3, fallback_y: float) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(pos.x, maxf(pos.y, fallback_y) + 5.0, pos.z),
			Vector3(pos.x, minf(pos.y, fallback_y) - 8.0, pos.z),
			1
		)
		var res: Dictionary = space_state.intersect_ray(q)
		if not res.is_empty() and res.has("position"):
			var col_obj: Object = res.get("collider") as Object
			var col_node: Node = col_obj as Node
			if col_node == null or (not col_node.is_in_group("Enemie") and not col_node.is_in_group("Player")):
				return res["position"] as Vector3
	return Vector3(pos.x, fallback_y, pos.z)
