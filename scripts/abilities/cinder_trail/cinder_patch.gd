class_name CinderPatch
extends Node3D

const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"
const SPARK_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"
const BURN_RES_PATH: String = "res://scripts/status_effects/burn/burn.tres"

static var _enemy_next_tick_msec: Dictionary = {}
static var _shared_flame_mat: StandardMaterial3D = null
static var _shared_flame_proc: ParticleProcessMaterial = null
static var _shared_spark_mat: StandardMaterial3D = null
static var _shared_spark_proc: ParticleProcessMaterial = null
static var _shared_quad: QuadMesh = null
static var _shape_cache: Dictionary = {}
static var _burn_effect: StatusEffectData = null

var radius: float = 1.15
var duration: float = 2.8
var fade_out_duration: float = 0.45
var tick_fire_damage: float = 7.0
var tick_interval: float = 0.35
var is_damage_authority: bool = true

var _elapsed: float = 0.0
var _fading_out: bool = false
var _overlapping_hitboxes: Array[HitboxComponent] = []
var _attack_area: AttackComponent = null
var _flames: GPUParticles3D = null
var _sparks: GPUParticles3D = null


static func _ensure_shared_resources() -> void:
	if _shared_quad == null:
		_shared_quad = QuadMesh.new()

	if _burn_effect == null and ResourceLoader.exists(BURN_RES_PATH):
		_burn_effect = load(BURN_RES_PATH) as StatusEffectData

	if _shared_flame_mat == null:
		var fm: StandardMaterial3D = StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fm.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			fm.albedo_texture = load(FIRE_TEX_PATH) as Texture2D
		fm.albedo_texture_force_srgb = true
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.billboard_keep_scale = true
		_shared_flame_mat = fm

	if _shared_flame_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.lifetime_randomness = 0.12
		pm.particle_flag_rotate_y = true
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_height = 0.14
		pm.emission_ring_radius = 0.72
		pm.emission_ring_inner_radius = 0.0
		pm.emission_ring_cone_angle = 90.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.direction = Vector3.UP
		pm.spread = 16.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.75
		pm.gravity = Vector3(0.0, 0.35, 0.0)
		pm.scale_min = 0.45
		pm.scale_max = 0.82
		pm.color = Color(2.1, 1.32, 0.65, 1.0)

		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.1, 0.48, 0.9])
		grad.colors = PackedColorArray([
			Color(1.0, 0.96, 0.78, 1.0),
			Color(0.98, 0.48, 0.08, 1.0),
			Color(0.88, 0.18, 0.02, 1.0)
		])
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp

		var a_curve: Curve = Curve.new()
		a_curve.add_point(Vector2(0.0, 0.88))
		a_curve.add_point(Vector2(0.45, 1.0))
		a_curve.add_point(Vector2(0.95, 0.0))
		var a_tex: CurveTexture = CurveTexture.new()
		a_tex.curve = a_curve
		pm.alpha_curve = a_tex
		_shared_flame_proc = pm

	if _shared_spark_mat == null:
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.render_priority = 1
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.vertex_color_use_as_albedo = true
		sm.vertex_color_is_srgb = true
		if ResourceLoader.exists(SPARK_TEX_PATH):
			sm.albedo_texture = load(SPARK_TEX_PATH) as Texture2D
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.billboard_keep_scale = true
		_shared_spark_mat = sm

	if _shared_spark_proc == null:
		var spm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		spm.emission_ring_axis = Vector3.UP
		spm.emission_ring_height = 0.2
		spm.emission_ring_radius = 0.75
		spm.emission_ring_inner_radius = 0.0
		spm.emission_ring_cone_angle = 90.0
		spm.direction = Vector3.UP
		spm.spread = 22.0
		spm.initial_velocity_min = 0.4
		spm.initial_velocity_max = 1.5
		spm.gravity = Vector3(0.0, 1.0, 0.0)
		spm.scale_min = 0.04
		spm.scale_max = 0.08
		spm.color = Color(2.5, 1.25, 0.45, 1.0)
		_shared_spark_proc = spm


static func _get_cached_shape(p_radius: float) -> CylinderShape3D:
	var key: int = maxi(10, int(roundf(p_radius * 20.0)))
	if _shape_cache.has(key):
		return _shape_cache[key] as CylinderShape3D
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = float(key) / 20.0
	cyl.height = 1.2
	_shape_cache[key] = cyl
	return cyl


func setup_cinder(
	caster: Node3D,
	p_radius: float,
	p_duration: float,
	p_tick_damage: float,
	p_tick_interval: float,
	p_is_auth: bool
) -> void:
	radius = maxf(0.4, p_radius)
	duration = maxf(0.8, p_duration)
	tick_fire_damage = maxf(0.5, p_tick_damage)
	tick_interval = maxf(0.1, p_tick_interval)
	is_damage_authority = p_is_auth

	_ensure_shared_resources()

	_attack_area = AttackComponent.new()
	_attack_area.name = "AttackComponent"
	_attack_area.caster = caster
	if caster != null:
		_attack_area.set_meta("caster_authority", caster.get_multiplayer_authority())
	_attack_area.collision_layer = 4
	_attack_area.collision_mask = 8
	_attack_area.knockback_force = 0.0
	_attack_area.can_headshot = false
	_attack_area.ignore_caster = true
	if _burn_effect != null:
		var burn_app: StatusEffectApplication = StatusEffectApplication.new()
		burn_app.effect = _burn_effect
		burn_app.duration = 2.5
		burn_app.apply_chance = 0.20
		_attack_area.status_effects_to_apply = [burn_app]

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.position = Vector3(0.0, 0.5, 0.0)
	col.shape = _get_cached_shape(radius)
	_attack_area.add_child(col)
	add_child(_attack_area)

	# On gère nous-mêmes les ticks périodiques sans hit_entities permanent
	_attack_area.is_active_for_network = false
	_attack_area.damage_physical = 0.0
	_attack_area.damage_fire = tick_fire_damage

	if is_damage_authority:
		_attack_area.monitoring = true
		_attack_area.monitorable = false
		_attack_area.area_entered.connect(_on_hitbox_entered)
		_attack_area.area_exited.connect(_on_hitbox_exited)
	else:
		_attack_area.monitoring = false
		_attack_area.monitorable = false

	var scale_mult: float = clampf(radius / 1.0, 0.5, 2.4)
	_flames = GPUParticles3D.new()
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.visibility_range_end = 42.0
	_flames.material_override = _shared_flame_mat
	_flames.process_material = _shared_flame_proc
	_flames.draw_pass_1 = _shared_quad
	_flames.amount = 8
	_flames.lifetime = 0.45
	_flames.fixed_fps = 30
	_flames.position.y = 0.18
	_flames.scale = Vector3.ONE * scale_mult
	add_child(_flames)

	_sparks = GPUParticles3D.new()
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.visibility_range_end = 36.0
	_sparks.material_override = _shared_spark_mat
	_sparks.process_material = _shared_spark_proc
	_sparks.draw_pass_1 = _shared_quad
	_sparks.amount = 5
	_sparks.lifetime = 0.55
	_sparks.fixed_fps = 30
	_sparks.position.y = 0.1
	_sparks.scale = Vector3.ONE * scale_mult
	add_child(_sparks)

	set_physics_process(false)


func _on_hitbox_entered(area: Area3D) -> void:
	if not is_damage_authority or _fading_out:
		return
	var hb: HitboxComponent = area as HitboxComponent
	if hb == null:
		return
	var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
	if entity == null or entity.is_in_group("Player"):
		return
	if not _overlapping_hitboxes.has(hb):
		_overlapping_hitboxes.append(hb)
	set_physics_process(true)
	_tick_overlapping_enemies()


func _on_hitbox_exited(area: Area3D) -> void:
	var hb: HitboxComponent = area as HitboxComponent
	if hb != null:
		_overlapping_hitboxes.erase(hb)
	if _overlapping_hitboxes.is_empty():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_damage_authority or _fading_out:
		set_physics_process(false)
		return
	_tick_overlapping_enemies()


func _tick_overlapping_enemies() -> void:
	if _attack_area == null or _overlapping_hitboxes.is_empty():
		set_physics_process(false)
		return

	if _enemy_next_tick_msec.size() > 96:
		_enemy_next_tick_msec.clear()

	var now_ms: int = Time.get_ticks_msec()
	var step_ms: int = maxi(80, int(roundf(tick_interval * 1000.0)))

	for i: int in range(_overlapping_hitboxes.size() - 1, -1, -1):
		var hb: HitboxComponent = _overlapping_hitboxes[i]
		if hb == null or not is_instance_valid(hb) or hb.is_queued_for_deletion():
			_overlapping_hitboxes.remove_at(i)
			continue
		var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
		if entity == null or not is_instance_valid(entity):
			_overlapping_hitboxes.remove_at(i)
			continue

		var eid: int = entity.get_instance_id()
		var next_ok: int = int(_enemy_next_tick_msec.get(eid, 0))
		if now_ms >= next_ok:
			_enemy_next_tick_msec[eid] = now_ms + step_ms
			_attack_area.damage_physical = 0.0
			_attack_area.damage_fire = tick_fire_damage
			hb.receive_hit(_attack_area)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _fading_out and _elapsed >= maxf(0.1, duration - fade_out_duration):
		_fading_out = true
		_overlapping_hitboxes.clear()
		set_physics_process(false)
		if _attack_area != null and is_instance_valid(_attack_area):
			_attack_area.set_deferred("monitoring", false)
		if _flames != null:
			_flames.emitting = false
		if _sparks != null:
			_sparks.emitting = false

	if _elapsed >= duration:
		queue_free()
