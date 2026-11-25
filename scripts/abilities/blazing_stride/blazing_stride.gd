extends Node3D

const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"
const SPARK_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"
const BURN_RES_PATH: String = "res://scripts/status_effects/burn/burn.tres"
const MODIFIER_SOURCE: String = "blazing_stride"
const META_ACTIVE_ID: String = "blazing_stride_active_id"

static var _foot_ring_mesh: TorusMesh = null
static var _foot_ring_mat: StandardMaterial3D = null
static var _sprint_spark_quad: QuadMesh = null
static var _sprint_spark_mat: StandardMaterial3D = null
static var _sprint_spark_proc: ParticleProcessMaterial = null

@export var buff_duration: float = 4.5
@export var speed_bonus_percent: float = 0.60
@export var patch_duration: float = 3.4
@export var patch_spacing: float = 0.85
@export var tick_interval: float = 0.30

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _stats_comp: StatsComponent = null
var _health_comp: HealthComponent = null
var _foot_ring: MeshInstance3D = null
var _sprint_sparks: GPUParticles3D = null

var _elapsed: float = 0.0
var _dist_accum: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _scaled_fire_dmg: float = 14.0
var _scaled_radius: float = 2.25
var _is_auth: bool = true
var _modifier_active: bool = false


static func _ensure_runner_visuals() -> void:
	if _foot_ring_mesh == null:
		_foot_ring_mesh = TorusMesh.new()
		_foot_ring_mesh.inner_radius = 0.56
		_foot_ring_mesh.outer_radius = 0.78
		_foot_ring_mesh.rings = 18
		_foot_ring_mesh.ring_segments = 6

	if _foot_ring_mat == null:
		_foot_ring_mat = StandardMaterial3D.new()
		_foot_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_foot_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_foot_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_foot_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_foot_ring_mat.albedo_color = Color(2.6, 1.05, 0.22, 0.72)

	if _sprint_spark_quad == null:
		_sprint_spark_quad = QuadMesh.new()
		_sprint_spark_quad.size = Vector2(0.14, 0.14)

	if _sprint_spark_mat == null:
		_sprint_spark_mat = StandardMaterial3D.new()
		_sprint_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sprint_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_sprint_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sprint_spark_mat.vertex_color_use_as_albedo = true
		_sprint_spark_mat.vertex_color_is_srgb = true
		if ResourceLoader.exists(SPARK_TEX_PATH):
			_sprint_spark_mat.albedo_texture = load(SPARK_TEX_PATH) as Texture2D
		_sprint_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_sprint_spark_mat.billboard_keep_scale = true

	if _sprint_spark_proc == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_height = 0.12
		pm.emission_ring_radius = 0.65
		pm.emission_ring_inner_radius = 0.42
		pm.direction = Vector3.UP
		pm.spread = 28.0
		pm.initial_velocity_min = 0.9
		pm.initial_velocity_max = 2.4
		pm.gravity = Vector3(0.0, 1.4, 0.0)
		pm.scale_min = 0.45
		pm.scale_max = 1.05
		pm.color = Color(2.8, 1.35, 0.35, 0.9)
		_sprint_spark_proc = pm


func _ready() -> void:
	_ensure_runner_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_foot_ring = MeshInstance3D.new()
	_foot_ring.mesh = _foot_ring_mesh
	_foot_ring.material_override = _foot_ring_mat
	_foot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_foot_ring.position = Vector3(0.0, 0.08, 0.0)
	add_child(_foot_ring)

	_sprint_sparks = GPUParticles3D.new()
	_sprint_sparks.material_override = _sprint_spark_mat
	_sprint_sparks.process_material = _sprint_spark_proc
	_sprint_sparks.draw_pass_1 = _sprint_spark_quad
	_sprint_sparks.amount = 14
	_sprint_sparks.lifetime = 0.42
	_sprint_sparks.fixed_fps = 30
	_sprint_sparks.visibility_range_end = 42.0
	_sprint_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprint_sparks.position = Vector3(0.0, 0.10, 0.0)
	add_child(_sprint_sparks)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())

	global_position = _caster.global_position
	_last_pos = _caster.global_position

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)
		_scaled_radius = maxf(0.8, scaling_component.final_impact_radius)
	if attack_component != null:
		_scaled_fire_dmg = maxf(1.0, attack_component.damage_fire)

	_stats_comp = _caster.find_child("StatsComponent", true, false) as StatsComponent
	_health_comp = _caster.get_node_or_null("HealthComponent") as HealthComponent

	if _is_auth and _stats_comp != null:
		_caster.set_meta(META_ACTIVE_ID, get_instance_id())
		_stats_comp.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, speed_bonus_percent, MODIFIER_SOURCE)
		_modifier_active = true

	SpellAudioManager.play_fire_cast(self, global_position, 1.16, -1.6)
	SpellAudioManager.attach_fire_loop(self, -7.2, 9.5, 36.0)
	_spawn_blazing_patch(_caster.global_position)


func _process(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster) or _is_caster_dead():
		_finish_stride()
		return

	_elapsed += delta
	if _elapsed >= buff_duration:
		_finish_stride()
		return

	global_position = _caster.global_position
	if _foot_ring != null:
		_foot_ring.rotate_y(delta * 5.2)
		var pulse: float = 0.94 + 0.10 * sin(_elapsed * 14.0)
		_foot_ring.scale = Vector3(pulse, 1.0, pulse)

	var cur_flat: Vector3 = Vector3(_caster.global_position.x, 0.0, _caster.global_position.z)
	var prev_flat: Vector3 = Vector3(_last_pos.x, 0.0, _last_pos.z)
	var step_d: float = cur_flat.distance_to(prev_flat)
	_last_pos = _caster.global_position
	_dist_accum += step_d

	if _dist_accum >= patch_spacing:
		_dist_accum = fmod(_dist_accum, patch_spacing)
		_spawn_blazing_patch(_caster.global_position)


func _exit_tree() -> void:
	_clear_speed_modifier()
	SpellAudioManager.stop_attached_loop(self)


func _is_caster_dead() -> bool:
	if _caster == null or not is_instance_valid(_caster):
		return true
	if _caster.get("is_dead") == true:
		return true
	if _health_comp != null and is_instance_valid(_health_comp) and _health_comp.current_health <= 0.0:
		return true
	return false


func _finish_stride() -> void:
	_clear_speed_modifier()
	SpellAudioManager.stop_attached_loop(self)
	queue_free()


func _clear_speed_modifier() -> void:
	if not _modifier_active:
		return
	_modifier_active = false
	if _stats_comp == null or not is_instance_valid(_stats_comp):
		return
	if _caster != null and is_instance_valid(_caster) and _caster.has_meta(META_ACTIVE_ID):
		var owner_id: int = int(_caster.get_meta(META_ACTIVE_ID))
		if owner_id != get_instance_id():
			return
		_caster.remove_meta(META_ACTIVE_ID)
	_stats_comp.remove_modifier_by_source(MODIFIER_SOURCE)


func _spawn_blazing_patch(origin_pos: Vector3) -> void:
	var spawn_pos: Vector3 = origin_pos
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin_pos + Vector3(0.0, 1.2, 0.0),
			origin_pos - Vector3(0.0, 3.8, 0.0),
			1
		)
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			spawn_pos = hit["position"] as Vector3

	var patch: BlazingPatch = BlazingPatch.new()
	get_tree().root.add_child(patch)
	patch.global_position = spawn_pos
	patch.setup_blazing(_caster, _scaled_radius, patch_duration, _scaled_fire_dmg, tick_interval, _is_auth)


class BlazingPatch extends Node3D:
	static var _enemy_next_tick_msec: Dictionary = {}
	static var _shared_flame_mat: StandardMaterial3D = null
	static var _shared_flame_proc: ParticleProcessMaterial = null
	static var _shared_spark_mat: StandardMaterial3D = null
	static var _shared_spark_proc: ParticleProcessMaterial = null
	static var _shared_quad: QuadMesh = null
	static var _shape_cache: Dictionary = {}
	static var _burn_effect: StatusEffectData = null

	var radius: float = 2.25
	var duration: float = 3.4
	var fade_out_duration: float = 0.50
	var tick_fire_damage: float = 14.0
	var tick_interval: float = 0.30
	var is_damage_authority: bool = true

	var _elapsed: float = 0.0
	var _fading_out: bool = false
	var _overlapping_hitboxes: Array[HitboxComponent] = []
	var _attack_area: AttackComponent = null
	var _flames: GPUParticles3D = null
	var _sparks: GPUParticles3D = null

	static func _ensure_patch_resources() -> void:
		if _shared_quad == null:
			_shared_quad = QuadMesh.new()

		if _burn_effect == null and ResourceLoader.exists(BURN_RES_PATH):
			_burn_effect = load(BURN_RES_PATH) as StatusEffectData

		if _shared_flame_mat == null:
			var fm: StandardMaterial3D = StandardMaterial3D.new()
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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
			pm.lifetime_randomness = 0.16
			pm.particle_flag_rotate_y = true
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_height = 0.18
			pm.emission_ring_radius = 0.85
			pm.emission_ring_inner_radius = 0.0
			pm.emission_ring_cone_angle = 90.0
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.direction = Vector3.UP
			pm.spread = 15.0
			pm.initial_velocity_min = 0.65
			pm.initial_velocity_max = 1.65
			pm.gravity = Vector3(0.0, 0.75, 0.0)
			pm.scale_min = 0.62
			pm.scale_max = 1.18
			pm.color = Color(2.35, 1.28, 0.52, 0.92)

			var grad: Gradient = Gradient.new()
			grad.offsets = PackedFloat32Array([0.05, 0.48, 0.95])
			grad.colors = PackedColorArray([
				Color(1.0, 0.96, 0.72, 0.95),
				Color(1.0, 0.44, 0.06, 0.85),
				Color(0.78, 0.12, 0.01, 0.0)
			])
			var ramp: GradientTexture1D = GradientTexture1D.new()
			ramp.gradient = grad
			pm.color_ramp = ramp
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
			spm.emission_ring_height = 0.22
			spm.emission_ring_radius = 0.88
			spm.emission_ring_inner_radius = 0.0
			spm.emission_ring_cone_angle = 90.0
			spm.direction = Vector3.UP
			spm.spread = 20.0
			spm.initial_velocity_min = 0.9
			spm.initial_velocity_max = 2.5
			spm.gravity = Vector3(0.0, 1.3, 0.0)
			spm.scale_min = 0.05
			spm.scale_max = 0.10
			spm.color = Color(2.8, 1.35, 0.42, 1.0)
			_shared_spark_proc = spm

	static func _get_cached_shape(p_radius: float) -> CylinderShape3D:
		var key: int = maxi(10, int(roundf(p_radius * 20.0)))
		if _shape_cache.has(key):
			return _shape_cache[key] as CylinderShape3D
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = float(key) / 20.0
		cyl.height = 2.0
		_shape_cache[key] = cyl
		return cyl

	func setup_blazing(
		caster: Node3D,
		p_radius: float,
		p_duration: float,
		p_tick_damage: float,
		p_tick_interval: float,
		p_is_auth: bool
	) -> void:
		radius = maxf(0.6, p_radius)
		duration = maxf(0.8, p_duration)
		tick_fire_damage = maxf(0.5, p_tick_damage)
		tick_interval = maxf(0.1, p_tick_interval)
		is_damage_authority = p_is_auth

		_ensure_patch_resources()

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
			burn_app.duration = 3.0
			burn_app.apply_chance = 0.35
			_attack_area.status_effects_to_apply = [burn_app]

		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.position = Vector3(0.0, 0.95, 0.0)
		col.shape = _get_cached_shape(radius)
		_attack_area.add_child(col)
		add_child(_attack_area)

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

		var scale_mult: float = clampf(radius / 1.15, 0.8, 3.2)
		_flames = GPUParticles3D.new()
		_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.visibility_range_end = 44.0
		_flames.material_override = _shared_flame_mat
		_flames.process_material = _shared_flame_proc
		_flames.draw_pass_1 = _shared_quad
		_flames.amount = 13
		_flames.lifetime = 0.56
		_flames.fixed_fps = 30
		_flames.position.y = 0.22
		_flames.scale = Vector3.ONE * scale_mult
		add_child(_flames)

		_sparks = GPUParticles3D.new()
		_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sparks.visibility_range_end = 38.0
		_sparks.material_override = _shared_spark_mat
		_sparks.process_material = _shared_spark_proc
		_sparks.draw_pass_1 = _shared_quad
		_sparks.amount = 7
		_sparks.lifetime = 0.65
		_sparks.fixed_fps = 30
		_sparks.position.y = 0.14
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
		var fade_start: float = maxf(0.1, duration - fade_out_duration)
		if _elapsed >= fade_start:
			if not _fading_out:
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
