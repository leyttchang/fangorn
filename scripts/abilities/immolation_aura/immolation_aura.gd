extends Node3D

const SHADER_PATH: String = "res://scripts/abilities/immolation_aura/immolation_aura.gdshader"
const SPARK_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"
const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"

static var _unit_sphere_mesh: SphereMesh = null
static var _aura_shader: Shader = null
static var _ember_quad: QuadMesh = null
static var _ember_mat: StandardMaterial3D = null

@export var aura_duration: float = 7.0
@export var tick_interval: float = 0.35
@export var center_height_offset: float = 0.9

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _health_comp: HealthComponent = null
var _sphere_mi: MeshInstance3D = null
var _sphere_mat: ShaderMaterial = null
var _embers: GPUParticles3D = null

var _elapsed: float = 0.0
var _tick_accum: float = 0.0
var _final_radius: float = 5.4
var _is_auth: bool = true
var _active: bool = false
var _hitbox_cache: Dictionary = {}


static func _ensure_shared_visuals() -> void:
	if _unit_sphere_mesh == null:
		_unit_sphere_mesh = SphereMesh.new()
		_unit_sphere_mesh.radius = 1.0
		_unit_sphere_mesh.height = 2.0
		_unit_sphere_mesh.radial_segments = 96
		_unit_sphere_mesh.rings = 48

	if _aura_shader == null and ResourceLoader.exists(SHADER_PATH):
		_aura_shader = load(SHADER_PATH) as Shader

	if _ember_quad == null:
		_ember_quad = QuadMesh.new()
		_ember_quad.size = Vector2(0.18, 0.18)

	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.vertex_color_is_srgb = true
		if ResourceLoader.exists(FIRE_TEX_PATH):
			_ember_mat.albedo_texture = load(FIRE_TEX_PATH) as Texture2D
		elif ResourceLoader.exists(SPARK_TEX_PATH):
			_ember_mat.albedo_texture = load(SPARK_TEX_PATH) as Texture2D
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.billboard_keep_scale = true


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_sphere_mat = ShaderMaterial.new()
	_sphere_mat.shader = _aura_shader
	_sphere_mat.set_shader_parameter("fade_factor", 1.0)

	_sphere_mi = MeshInstance3D.new()
	_sphere_mi.mesh = _unit_sphere_mesh
	_sphere_mi.material_override = _sphere_mat
	_sphere_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere_mi.extra_cull_margin = 2.0
	add_child(_sphere_mi)

	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3.UP
	pm.spread = 24.0
	pm.initial_velocity_min = 0.45
	pm.initial_velocity_max = 1.35
	pm.gravity = Vector3(0.0, 0.85, 0.0)
	pm.scale_min = 0.45
	pm.scale_max = 1.05
	pm.color = Color(2.4, 1.15, 0.30, 0.78)
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.92, 0.55, 0.0),
		Color(1.0, 0.48, 0.08, 0.85),
		Color(0.75, 0.12, 0.02, 0.0)
	])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp

	_embers = GPUParticles3D.new()
	_embers.material_override = _ember_mat
	_embers.process_material = pm
	_embers.draw_pass_1 = _ember_quad
	_embers.amount = 18
	_embers.lifetime = 0.85
	_embers.fixed_fps = 30
	_embers.visibility_range_end = 48.0
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_embers)


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
		_final_radius = maxf(1.5, scaling_component.final_impact_radius)

	_health_comp = _caster.get_node_or_null("HealthComponent") as HealthComponent
	global_position = _caster.global_position + Vector3(0.0, center_height_offset, 0.0)

	if _sphere_mi != null:
		_sphere_mi.scale = Vector3.ONE * (_final_radius * 0.25)
	if _embers != null:
		var proc: ParticleProcessMaterial = _embers.process_material as ParticleProcessMaterial
		if proc != null:
			proc.emission_sphere_radius = _final_radius * 0.88

	_active = true
	_tick_accum = tick_interval

	SpellAudioManager.play_fire_cast(self, global_position, 0.88, -1.5)
	SpellAudioManager.attach_fire_loop(self, -6.4, 11.0, 42.0)

	if _is_auth:
		_apply_aura_tick()
		_tick_accum = 0.0


func _process(delta: float) -> void:
	if not _active or _caster == null or not is_instance_valid(_caster) or _is_caster_dead():
		_expire_aura()
		return

	_elapsed += delta
	if _elapsed >= aura_duration:
		_expire_aura()
		return

	global_position = _caster.global_position + Vector3(0.0, center_height_offset, 0.0)

	var intro_t: float = clampf(_elapsed / 0.18, 0.0, 1.0)
	var ease_intro: float = 1.0 - pow(1.0 - intro_t, 3.0)
	var breath: float = 1.0 + 0.012 * sin(_elapsed * 4.2)
	if _sphere_mi != null:
		_sphere_mi.scale = Vector3.ONE * (_final_radius * lerpf(0.25, 1.0, ease_intro) * breath)

	var fade_out_window: float = 0.45
	if _sphere_mat != null:
		var fade_val: float = 1.0
		if _elapsed > aura_duration - fade_out_window:
			fade_val = clampf((aura_duration - _elapsed) / fade_out_window, 0.0, 1.0)
			if _embers != null and _embers.emitting:
				_embers.emitting = false
		_sphere_mat.set_shader_parameter("fade_factor", fade_val * ease_intro)

	if _is_auth:
		_tick_accum += delta
		if _tick_accum >= tick_interval:
			_tick_accum = fmod(_tick_accum, tick_interval)
			_apply_aura_tick()


func _exit_tree() -> void:
	SpellAudioManager.stop_attached_loop(self)


func _is_caster_dead() -> bool:
	if _caster == null or not is_instance_valid(_caster):
		return true
	if _caster.get("is_dead") == true:
		return true
	if _health_comp != null and is_instance_valid(_health_comp) and _health_comp.current_health <= 0.0:
		return true
	return false


func _expire_aura() -> void:
	_active = false
	SpellAudioManager.stop_attached_loop(self)
	queue_free()


func _apply_aura_tick() -> void:
	if attack_component == null or _caster == null or not is_instance_valid(_caster):
		return

	var center: Vector3 = _caster.global_position + Vector3(0.0, center_height_offset, 0.0)
	attack_component.global_position = _caster.global_position
	var reach: float = _final_radius + 0.35
	var reach_sq: float = reach * reach

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_health <= 0.0:
			continue

		var anchor: Vector3 = _get_mob_anchor_pos(mob)
		if center.distance_squared_to(anchor) > reach_sq:
			continue

		var hb: HitboxComponent = _resolve_mob_hitbox(mob)
		if hb != null:
			hb.receive_hit(attack_component)


func _resolve_mob_hitbox(mob: Node3D) -> HitboxComponent:
	var mid: int = mob.get_instance_id()
	var cached_hb: HitboxComponent = _hitbox_cache.get(mid) as HitboxComponent
	if cached_hb != null and is_instance_valid(cached_hb):
		return cached_hb

	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	if hb != null:
		_hitbox_cache[mid] = hb
	return hb


static func _get_mob_anchor_pos(mob: Node3D) -> Vector3:
	var cs: CollisionShape3D = mob.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		if cs.position.y < 0.05:
			return cs.global_position
		return mob.global_position + Vector3(cs.position.x, clampf(cs.position.y, 0.4, 1.4), cs.position.z)
	return mob.global_position + Vector3(0.0, 1.0, 0.0)
