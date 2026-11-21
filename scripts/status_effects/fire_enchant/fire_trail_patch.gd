class_name FireTrailPatch
extends Node3D

## Zone de feu au sol ultra-optimisée laissée derrière un monstre affecté par l'enchantement de feu :
## - 0 Decal Forward+, 0 OmniLight3D, 0 fumée, 0 .duplicate() de matériau ou de shape par instance !
## - Partage statiquement les matériaux/process de flammes vives et d'étincelles entre toutes les flaques
## - Anti-cumul global de DoT entre flaques adjacentes

const FIRE_TEX_PATH := "res://assets/LeLu's Noise Pack/T_fire01.png"
const SPARK_TEX_PATH := "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"

static var _player_next_tick_msec: Dictionary = {}
static var _shared_flame_mat: StandardMaterial3D = null
static var _shared_flame_process: ParticleProcessMaterial = null
static var _shared_spark_mat: StandardMaterial3D = null
static var _shared_spark_process: ParticleProcessMaterial = null
static var _shared_quad: QuadMesh = null
static var _shape_cache: Dictionary = {} # int(radius_step) -> CylinderShape3D

@export var radius: float = 1.05
@export var duration: float = 3.5
@export var fade_out_duration: float = 0.55
@export var tick_damage: float = 5.0
@export var tick_interval: float = 0.4
@export var particle_density: float = 8.0
@export var custom_vfx_scene: PackedScene

var _elapsed: float = 0.0
var _fading_out: bool = false
var _is_server_auth: bool = true
var _overlapping_hitboxes: Array[HitboxComponent] = []
var _custom_vfx_spawned: bool = false

var _flames_particles: GPUParticles3D = null
var _sparks_particles: GPUParticles3D = null

@onready var attack_component: AttackComponent = get_node_or_null("AttackComponent") as AttackComponent


static func _ensure_shared_visual_resources() -> void:
	if _shared_quad == null:
		_shared_quad = QuadMesh.new()

	if _shared_flame_mat == null:
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fm.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			fm.albedo_texture = load(FIRE_TEX_PATH)
		fm.albedo_texture_force_srgb = true
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.billboard_keep_scale = true
		_shared_flame_mat = fm

	if _shared_flame_process == null:
		var pm := ParticleProcessMaterial.new()
		pm.lifetime_randomness = 0.1
		pm.particle_flag_rotate_y = true
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_height = 0.18
		pm.emission_ring_radius = 0.78
		pm.emission_ring_inner_radius = 0.0
		pm.emission_ring_cone_angle = 90.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.direction = Vector3.UP
		pm.spread = 18.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.85
		pm.gravity = Vector3(0.0, 0.35, 0.0)
		pm.scale_min = 0.55
		pm.scale_max = 0.92
		pm.color = Color(1.98, 1.38, 0.86, 1.0)

		# Pur dégradé de flammes vives (jaune chaud -> orange vif -> rouge orangé), ZÉRO gris/fumée
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.12, 0.45, 0.88])
		grad.colors = PackedColorArray([
			Color(1.0, 0.98, 0.82, 1.0),
			Color(0.96, 0.53, 0.08, 1.0),
			Color(0.92, 0.24, 0.03, 1.0)
		])
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp

		var a_curve := Curve.new()
		a_curve.add_point(Vector2(0.0, 0.9))
		a_curve.add_point(Vector2(0.42, 1.0))
		a_curve.add_point(Vector2(0.94, 0.0))
		var a_tex := CurveTexture.new()
		a_tex.curve = a_curve
		pm.alpha_curve = a_tex

		_shared_flame_process = pm

	if _shared_spark_mat == null:
		var sm := StandardMaterial3D.new()
		sm.render_priority = 1
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.vertex_color_use_as_albedo = true
		sm.vertex_color_is_srgb = true
		if ResourceLoader.exists(SPARK_TEX_PATH):
			sm.albedo_texture = load(SPARK_TEX_PATH)
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.billboard_keep_scale = true
		_shared_spark_mat = sm

	if _shared_spark_process == null:
		var spm := ParticleProcessMaterial.new()
		spm.lifetime_randomness = 0.15
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		spm.emission_ring_axis = Vector3.UP
		spm.emission_ring_height = 0.25
		spm.emission_ring_radius = 0.8
		spm.emission_ring_inner_radius = 0.0
		spm.emission_ring_cone_angle = 90.0
		spm.direction = Vector3.UP
		spm.spread = 20.0
		spm.initial_velocity_min = 0.45
		spm.initial_velocity_max = 1.65
		spm.gravity = Vector3(0.0, 1.1, 0.0)
		spm.scale_min = 0.04
		spm.scale_max = 0.085
		spm.color = Color(2.45, 1.25, 0.5, 1.0)

		var sa_curve := Curve.new()
		sa_curve.add_point(Vector2(0.0, 1.0))
		sa_curve.add_point(Vector2(0.65, 0.75))
		sa_curve.add_point(Vector2(1.0, 0.0))
		var sa_tex := CurveTexture.new()
		sa_tex.curve = sa_curve
		spm.alpha_curve = sa_tex

		_shared_spark_process = spm


static func _get_cached_cylinder_shape(p_radius: float) -> CylinderShape3D:
	var key: int = maxi(10, int(round(p_radius * 20.0)))
	if _shape_cache.has(key):
		return _shape_cache[key] as CylinderShape3D
	var cyl := CylinderShape3D.new()
	cyl.radius = float(key) / 20.0
	cyl.height = 0.75
	_shape_cache[key] = cyl
	return cyl


func setup_trail(
	p_radius: float,
	p_duration: float,
	p_tick_damage: float,
	p_tick_interval: float,
	p_custom_vfx: PackedScene = null
) -> void:
	radius = maxf(0.25, p_radius)
	duration = maxf(0.6, p_duration)
	tick_damage = maxf(0.0, p_tick_damage)
	tick_interval = maxf(0.08, p_tick_interval)
	if p_custom_vfx != null:
		custom_vfx_scene = p_custom_vfx
	if is_node_ready():
		_apply_configuration()


func setup(new_radius: float, new_duration: float) -> void:
	setup_trail(new_radius, new_duration, tick_damage, tick_interval, custom_vfx_scene)


func _ready() -> void:
	_is_server_auth = (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
	set_physics_process(false)
	_apply_configuration()


func _apply_configuration() -> void:
	fade_out_duration = clampf(fade_out_duration, 0.15, duration * 0.6)

	if attack_component != null:
		attack_component.is_active_for_network = false
		attack_component.base_damage = 0.0
		attack_component.damage_physical = 0.0
		attack_component.damage_fire = tick_damage
		attack_component.knockback_force = 0.0
		attack_component.can_headshot = false
		attack_component.ignore_caster = false
		attack_component.collision_layer = 16
		attack_component.collision_mask = 2

		var col := attack_component.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.shape = _get_cached_cylinder_shape(radius)

		if _is_server_auth and not _fading_out:
			attack_component.monitoring = true
			attack_component.monitorable = false
			if not attack_component.area_entered.is_connected(_on_hitbox_entered):
				attack_component.area_entered.connect(_on_hitbox_entered)
			if not attack_component.area_exited.is_connected(_on_hitbox_exited):
				attack_component.area_exited.connect(_on_hitbox_exited)
		else:
			attack_component.monitoring = false
			attack_component.monitorable = false

	_configure_visuals()


func _configure_visuals() -> void:
	if custom_vfx_scene != null:
		if not _custom_vfx_spawned:
			var custom_inst := custom_vfx_scene.instantiate()
			if custom_inst != null:
				custom_inst.name = "CustomTrailVFX"
				add_child(custom_inst)
				_custom_vfx_spawned = true
		return

	_ensure_shared_visual_resources()
	var scale_mult := clampf(radius / 1.0, 0.4, 2.5)

	if _flames_particles == null:
		_flames_particles = GPUParticles3D.new()
		_flames_particles.name = "TrailFlames"
		_flames_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames_particles.visibility_range_end = 44.0
		_flames_particles.visibility_range_end_margin = 7.0
		_flames_particles.material_override = _shared_flame_mat
		_flames_particles.process_material = _shared_flame_process
		_flames_particles.draw_pass_1 = _shared_quad
		_flames_particles.amount = 9
		_flames_particles.lifetime = 0.48
		_flames_particles.fixed_fps = 30
		_flames_particles.position.y = 0.22
		add_child(_flames_particles)
	_flames_particles.scale = Vector3.ONE * scale_mult

	if _sparks_particles == null:
		_sparks_particles = GPUParticles3D.new()
		_sparks_particles.name = "TrailSparks"
		_sparks_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sparks_particles.visibility_range_end = 38.0
		_sparks_particles.visibility_range_end_margin = 6.0
		_sparks_particles.material_override = _shared_spark_mat
		_sparks_particles.process_material = _shared_spark_process
		_sparks_particles.draw_pass_1 = _shared_quad
		_sparks_particles.amount = 6
		_sparks_particles.lifetime = 0.65
		_sparks_particles.fixed_fps = 30
		_sparks_particles.position.y = 0.1
		add_child(_sparks_particles)
	_sparks_particles.scale = Vector3.ONE * scale_mult


func _on_hitbox_entered(area: Area3D) -> void:
	if not _is_server_auth or _fading_out:
		return
	var hb := area as HitboxComponent
	if hb == null:
		return
	var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
	if entity == null or not entity.is_in_group("Player"):
		return
	if not _overlapping_hitboxes.has(hb):
		_overlapping_hitboxes.append(hb)
	set_physics_process(true)
	_process_overlapping_damage()


func _on_hitbox_exited(area: Area3D) -> void:
	var hb := area as HitboxComponent
	if hb != null:
		_overlapping_hitboxes.erase(hb)
	if _overlapping_hitboxes.is_empty():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not _is_server_auth or _fading_out:
		set_physics_process(false)
		return
	_process_overlapping_damage()


func _process_overlapping_damage() -> void:
	if attack_component == null or _overlapping_hitboxes.is_empty():
		set_physics_process(false)
		return

	if _player_next_tick_msec.size() > 32:
		_prune_stale_tick_entries()

	var now_ms: int = Time.get_ticks_msec()
	var step_ms: int = maxi(50, int(round(tick_interval * 1000.0)))

	for i in range(_overlapping_hitboxes.size() - 1, -1, -1):
		var hb := _overlapping_hitboxes[i]
		if hb == null or not is_instance_valid(hb) or hb.is_queued_for_deletion():
			_overlapping_hitboxes.remove_at(i)
			continue

		var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
		if entity == null or not entity.is_in_group("Player"):
			_overlapping_hitboxes.remove_at(i)
			continue
		if entity.get("is_dead") == true or (entity.has_method("is_dead") and entity.is_dead()):
			continue

		var pid: int = entity.get_instance_id()
		var next_allowed: int = int(_player_next_tick_msec.get(pid, 0))
		if now_ms >= next_allowed:
			_player_next_tick_msec[pid] = now_ms + step_ms
			attack_component.damage_physical = 0.0
			attack_component.damage_fire = tick_damage
			hb.receive_hit(attack_component)

	if _overlapping_hitboxes.is_empty():
		set_physics_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	var fade_start: float = maxf(0.0, duration - fade_out_duration)

	if _elapsed >= fade_start and not _fading_out:
		_begin_fade_out()

	if _elapsed >= duration:
		queue_free()


func fade_out_early() -> void:
	if _fading_out:
		return
	_elapsed = maxf(_elapsed, duration - fade_out_duration)
	_begin_fade_out()


func _begin_fade_out() -> void:
	_fading_out = true
	_overlapping_hitboxes.clear()
	set_physics_process(false)

	if attack_component != null and is_instance_valid(attack_component):
		attack_component.set_deferred("monitoring", false)

	if _flames_particles != null and is_instance_valid(_flames_particles):
		_flames_particles.emitting = false
	if _sparks_particles != null and is_instance_valid(_sparks_particles):
		_sparks_particles.emitting = false
	if _custom_vfx_spawned:
		_stop_particles_recursive(self)


func _stop_particles_recursive(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	for child in node.get_children():
		_stop_particles_recursive(child)


static func _prune_stale_tick_entries() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var to_erase: Array = []
	for pid in _player_next_tick_msec.keys():
		if now_ms - int(_player_next_tick_msec[pid]) > 15000:
			to_erase.append(pid)
	for pid in to_erase:
		_player_next_tick_msec.erase(pid)
