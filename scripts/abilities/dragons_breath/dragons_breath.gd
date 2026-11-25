extends Node3D

const CONE_SHADER_PATH: String = "res://scripts/abilities/dragons_breath/dragons_breath_cone.gdshader"
const FIRE_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_fire01.png"
const SIMPLEX_TEX_PATH: String = "res://assets/LeLu's Noise Pack/T_VFX_simplex_1.png"

const NOZZLE_ORB_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 orb_color : source_color = vec4(1.0, 0.65, 0.18, 1.0);
uniform float orb_intensity = 2.2;
uniform float orb_alpha = 0.72;

void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float soft_glow = pow(ndv, 2.35);
	ALBEDO = orb_color.rgb * orb_intensity;
	ALPHA = clamp(soft_glow * orb_alpha, 0.0, 0.88);
}
"""

static var _core_cone_mesh: CylinderMesh = null
static var _mid_cone_mesh: CylinderMesh = null
static var _outer_cone_mesh: CylinderMesh = null
static var _nozzle_orb_mesh: SphereMesh = null
static var _cone_shader: Shader = null
static var _orb_shader: Shader = null
static var _fire_tex: Texture2D = null
static var _simplex_tex: Texture2D = null
static var _ember_quad: QuadMesh = null
static var _ember_mat: StandardMaterial3D = null

@export var base_cone_length: float = 9.5
@export var cone_half_angle_deg: float = 30.0
@export var melee_forgiveness_dist: float = 2.4
@export var base_tick_interval: float = 0.18
@export var deploy_duration: float = 0.24
@export var extinguish_duration: float = 0.24
@export var overheat_ramp_time: float = 2.4

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _core_cone: MeshInstance3D = null
var _mid_cone: MeshInstance3D = null
var _outer_cone: MeshInstance3D = null
var _nozzle_orb: MeshInstance3D = null

var _core_mat: ShaderMaterial = null
var _mid_mat: ShaderMaterial = null
var _outer_mat: ShaderMaterial = null
var _orb_mat: ShaderMaterial = null

var _flame_particles: GPUParticles3D = null
var _flame_proc: ParticleProcessMaterial = null

var _caster: Node3D = null
var _is_channeling: bool = false
var _is_stopping: bool = false
var _is_auth: bool = true

var _tick_accum: float = 0.0
var _effective_tick: float = 0.18
var _cone_length: float = 9.5
var _aoe_mult: float = 1.0
var _spin_angle: float = 0.0
var _channel_time: float = 0.0
var _deploy_elapsed: float = 0.0
var _stop_elapsed: float = 0.0

var _hand_pos: Vector3 = Vector3.ZERO
var _aim_origin: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.FORWARD
var _hitbox_cache: Dictionary = {}


static func _ensure_shared_visuals() -> void:
	if _core_cone_mesh == null:
		_core_cone_mesh = CylinderMesh.new()
		_core_cone_mesh.top_radius = 0.14
		_core_cone_mesh.bottom_radius = 1.45
		_core_cone_mesh.height = 1.0
		_core_cone_mesh.radial_segments = 48
		_core_cone_mesh.rings = 20
		_core_cone_mesh.cap_top = false
		_core_cone_mesh.cap_bottom = false

	if _mid_cone_mesh == null:
		_mid_cone_mesh = CylinderMesh.new()
		_mid_cone_mesh.top_radius = 0.18
		_mid_cone_mesh.bottom_radius = 2.55
		_mid_cone_mesh.height = 1.0
		_mid_cone_mesh.radial_segments = 48
		_mid_cone_mesh.rings = 20
		_mid_cone_mesh.cap_top = false
		_mid_cone_mesh.cap_bottom = false

	if _outer_cone_mesh == null:
		_outer_cone_mesh = CylinderMesh.new()
		_outer_cone_mesh.top_radius = 0.22
		_outer_cone_mesh.bottom_radius = 3.45
		_outer_cone_mesh.height = 1.0
		_outer_cone_mesh.radial_segments = 48
		_outer_cone_mesh.rings = 20
		_outer_cone_mesh.cap_top = false
		_outer_cone_mesh.cap_bottom = false

	if _nozzle_orb_mesh == null:
		_nozzle_orb_mesh = SphereMesh.new()
		_nozzle_orb_mesh.radius = 0.24
		_nozzle_orb_mesh.height = 0.48
		_nozzle_orb_mesh.radial_segments = 24
		_nozzle_orb_mesh.rings = 12

	if _cone_shader == null and ResourceLoader.exists(CONE_SHADER_PATH):
		_cone_shader = load(CONE_SHADER_PATH) as Shader

	if _orb_shader == null:
		_orb_shader = Shader.new()
		_orb_shader.code = NOZZLE_ORB_SHADER_CODE

	if _fire_tex == null and ResourceLoader.exists(FIRE_TEX_PATH):
		_fire_tex = load(FIRE_TEX_PATH) as Texture2D

	if _simplex_tex == null and ResourceLoader.exists(SIMPLEX_TEX_PATH):
		_simplex_tex = load(SIMPLEX_TEX_PATH) as Texture2D

	if _ember_quad == null:
		_ember_quad = QuadMesh.new()
		_ember_quad.size = Vector2(0.48, 0.48)

	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.vertex_color_is_srgb = true
		if _fire_tex != null:
			_ember_mat.albedo_texture = _fire_tex
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.billboard_keep_scale = true


func _build_cone_material(
	core_col: Color,
	mid_col: Color,
	tip_col: Color,
	scroll_spd: float,
	tile_u_val: float,
	density: float,
	erode_b: float,
	turb: float,
	t_offset: float,
	b_reach: float
) -> ShaderMaterial:
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = _cone_shader
	if _fire_tex != null:
		sm.set_shader_parameter("fire_tex", _fire_tex)
	if _simplex_tex != null:
		sm.set_shader_parameter("simplex_tex", _simplex_tex)
	sm.set_shader_parameter("core_color", core_col)
	sm.set_shader_parameter("mid_color", mid_col)
	sm.set_shader_parameter("tip_color", tip_col)
	sm.set_shader_parameter("scroll_speed", scroll_spd)
	sm.set_shader_parameter("tile_u", tile_u_val)
	sm.set_shader_parameter("density_gain", density)
	sm.set_shader_parameter("erode_bias", erode_b)
	sm.set_shader_parameter("turb_strength", turb)
	sm.set_shader_parameter("time_offset", t_offset)
	sm.set_shader_parameter("blue_reach", b_reach)
	sm.set_shader_parameter("deploy_progress", 0.12)
	sm.set_shader_parameter("tail_cut", 0.0)
	sm.set_shader_parameter("overheat_ratio", 0.0)
	sm.set_shader_parameter("global_fade", 1.0)
	return sm


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_core_mat = _build_cone_material(
		Color(1.0, 0.95, 0.62, 1.0),
		Color(1.0, 0.48, 0.08, 1.0),
		Color(0.92, 0.16, 0.02, 1.0),
		2.65, 2.0, 0.56, -0.04, 0.16, 0.0, 0.54
	)
	_mid_mat = _build_cone_material(
		Color(1.0, 0.86, 0.38, 1.0),
		Color(1.0, 0.38, 0.05, 1.0),
		Color(0.84, 0.10, 0.02, 1.0),
		2.10, 2.0, 0.46, 0.04, 0.24, 1.85, 0.46
	)
	_outer_mat = _build_cone_material(
		Color(1.0, 0.74, 0.24, 1.0),
		Color(0.96, 0.30, 0.04, 1.0),
		Color(0.68, 0.06, 0.01, 1.0),
		1.65, 3.0, 0.36, 0.12, 0.34, 3.70, 0.36
	)

	_orb_mat = ShaderMaterial.new()
	_orb_mat.shader = _orb_shader
	_orb_mat.set_shader_parameter("orb_color", Color(1.0, 0.62, 0.16, 1.0))
	_orb_mat.set_shader_parameter("orb_intensity", 2.3)
	_orb_mat.set_shader_parameter("orb_alpha", 0.72)

	_core_cone = MeshInstance3D.new()
	_core_cone.mesh = _core_cone_mesh
	_core_cone.material_override = _core_mat
	_core_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_cone.extra_cull_margin = 2.0
	_core_cone.visible = false
	add_child(_core_cone)

	_mid_cone = MeshInstance3D.new()
	_mid_cone.mesh = _mid_cone_mesh
	_mid_cone.material_override = _mid_mat
	_mid_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mid_cone.extra_cull_margin = 2.0
	_mid_cone.visible = false
	add_child(_mid_cone)

	_outer_cone = MeshInstance3D.new()
	_outer_cone.mesh = _outer_cone_mesh
	_outer_cone.material_override = _outer_mat
	_outer_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outer_cone.extra_cull_margin = 2.0
	_outer_cone.visible = false
	add_child(_outer_cone)

	_nozzle_orb = MeshInstance3D.new()
	_nozzle_orb.mesh = _nozzle_orb_mesh
	_nozzle_orb.material_override = _orb_mat
	_nozzle_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nozzle_orb.visible = false
	add_child(_nozzle_orb)

	_flame_proc = ParticleProcessMaterial.new()
	_flame_proc.direction = Vector3(0.0, 0.0, -1.0)
	_flame_proc.spread = 24.0
	_flame_proc.initial_velocity_min = 11.5
	_flame_proc.initial_velocity_max = 18.5
	_flame_proc.damping_min = 2.5
	_flame_proc.damping_max = 5.5
	_flame_proc.gravity = Vector3(0.0, 1.1, 0.0)
	_flame_proc.angle_min = -180.0
	_flame_proc.angle_max = 180.0
	_flame_proc.scale_min = 0.45
	_flame_proc.scale_max = 1.45
	_flame_proc.color = Color(2.2, 1.15, 0.35, 0.85)
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.72, 0.90),
		Color(1.0, 0.46, 0.08, 0.78),
		Color(0.82, 0.14, 0.02, 0.42),
		Color(0.45, 0.04, 0.01, 0.0)
	])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = grad
	_flame_proc.color_ramp = ramp

	_flame_particles = GPUParticles3D.new()
	_flame_particles.material_override = _ember_mat
	_flame_particles.process_material = _flame_proc
	_flame_particles.draw_pass_1 = _ember_quad
	_flame_particles.amount = 44
	_flame_particles.lifetime = 0.58
	_flame_particles.fixed_fps = 30
	_flame_particles.visibility_range_end = 52.0
	_flame_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame_particles.emitting = false
	add_child(_flame_particles)


func start_channel(caster: Node3D, aim_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	var is_remote: bool = bool(aim_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())

	if attack_component != null:
		attack_component.on_execute(_caster, aim_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, aim_data)
		_aoe_mult = maxf(0.5, scaling_component.final_aoe_multiplier)
		_cone_length = maxf(3.0, scaling_component.final_impact_radius)
	else:
		_aoe_mult = 1.0
		_cone_length = base_cone_length

	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.06, base_tick_interval / cast_spd)
	_tick_accum = _effective_tick

	_channel_time = 0.0
	_deploy_elapsed = 0.0
	_stop_elapsed = 0.0
	_is_stopping = false
	_is_channeling = true

	_read_aim_data(aim_data)
	global_position = _hand_pos

	if _flame_particles != null:
		_flame_particles.emitting = true

	SpellAudioManager.play_fire_cast(self, _hand_pos, 0.90, -1.6)
	SpellAudioManager.attach_fire_loop(self, -5.2)
	_step_breath(0.0)


func update_channel(caster: Node3D, delta: float, aim_data: Dictionary) -> void:
	if _is_stopping:
		return
	_caster = caster
	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.06, base_tick_interval / cast_spd)
	_read_aim_data(aim_data)
	_step_breath(delta)


func update_remote_aim(_aim_point: Vector3, aim_dir: Vector3) -> void:
	if aim_dir.length_squared() > 0.001:
		_aim_dir = aim_dir.normalized()


func stop_channel() -> void:
	if _is_stopping:
		return
	_is_channeling = false
	_is_stopping = true
	_stop_elapsed = 0.0
	SpellAudioManager.stop_attached_loop(self)
	if _flame_particles != null:
		_flame_particles.emitting = false


func _exit_tree() -> void:
	SpellAudioManager.stop_attached_loop(self)


func _process(delta: float) -> void:
	if _is_stopping:
		_step_extinguish(delta)
		return

	if _is_channeling and not _is_auth:
		if _caster != null and is_instance_valid(_caster):
			var left_hand: Node3D = _caster.find_child("MainGauche", true, false) as Node3D
			_hand_pos = left_hand.global_position if left_hand != null else (_caster.global_position + Vector3(0.0, 1.25, 0.0))
			_aim_origin = _hand_pos
		_step_breath(delta)


func _read_aim_data(aim_data: Dictionary) -> void:
	var fallback_hand: Vector3 = _caster.global_position + Vector3(0.0, 1.25, 0.0) if _caster != null and is_instance_valid(_caster) else Vector3.ZERO
	_hand_pos = aim_data.get("hand_pos", fallback_hand) as Vector3
	_aim_origin = aim_data.get("aim_origin", _hand_pos) as Vector3
	var d: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
	_aim_dir = d.normalized() if d.length_squared() > 0.001 else Vector3.FORWARD


func _step_breath(delta: float) -> void:
	if not _is_channeling or _caster == null or not is_instance_valid(_caster):
		stop_channel()
		return

	_channel_time += delta
	_deploy_elapsed = minf(deploy_duration, _deploy_elapsed + delta)
	_spin_angle = fmod(_spin_angle + delta * 2.9, TAU)

	var t_in: float = clampf(_deploy_elapsed / maxf(0.04, deploy_duration), 0.0, 1.0)
	var deploy_ease: float = 1.0 - pow(1.0 - t_in, 3.0)
	var overheat: float = clampf(_channel_time / maxf(0.2, overheat_ramp_time), 0.0, 1.0)

	global_position = _hand_pos
	_apply_shader_state(lerpf(0.14, 1.10, deploy_ease), 0.0, overheat, 1.0)
	_update_cone_transforms(
		_cone_length * lerpf(0.08, 1.0, deploy_ease),
		_aoe_mult * lerpf(0.30, 1.0, deploy_ease),
		lerpf(0.25, 1.0, deploy_ease),
		overheat
	)

	if _is_auth:
		_tick_accum += delta
		if _tick_accum >= _effective_tick:
			_tick_accum = fmod(_tick_accum, _effective_tick)
			_apply_cone_damage_tick()


func _step_extinguish(delta: float) -> void:
	_stop_elapsed += delta
	if _stop_elapsed >= extinguish_duration:
		queue_free()
		return

	if _caster != null and is_instance_valid(_caster):
		var left_hand: Node3D = _caster.find_child("MainGauche", true, false) as Node3D
		if left_hand != null:
			_hand_pos = left_hand.global_position
		var cam: Camera3D = _caster.get_node_or_null("Camera3D") as Camera3D
		if cam != null and _is_auth:
			_aim_origin = cam.global_position
			var cf: Vector3 = -cam.global_transform.basis.z
			if cf.length_squared() > 0.001:
				_aim_dir = cf.normalized()

	_spin_angle = fmod(_spin_angle + delta * 3.4, TAU)
	var t_out: float = clampf(_stop_elapsed / maxf(0.04, extinguish_duration), 0.0, 1.0)
	var tail_val: float = pow(t_out, 0.85) * 1.08
	var rem_fade: float = 1.0 - pow(t_out, 1.35)
	var overheat: float = clampf(_channel_time / maxf(0.2, overheat_ramp_time), 0.0, 1.0)

	global_position = _hand_pos
	_apply_shader_state(1.10, tail_val, overheat, rem_fade)
	_update_cone_transforms(
		_cone_length * lerpf(1.0, 1.08, t_out),
		_aoe_mult * lerpf(1.0, 0.82, t_out),
		maxf(0.0, 1.0 - t_out * 2.2),
		overheat
	)


func _apply_shader_state(deploy_val: float, tail_val: float, overheat: float, fade_val: float) -> void:
	var mats: Array[ShaderMaterial] = [_core_mat, _mid_mat, _outer_mat]
	for sm: ShaderMaterial in mats:
		if sm != null:
			sm.set_shader_parameter("deploy_progress", deploy_val)
			sm.set_shader_parameter("tail_cut", tail_val)
			sm.set_shader_parameter("overheat_ratio", overheat)
			sm.set_shader_parameter("global_fade", fade_val)

	if _orb_mat != null:
		var warm_orb: Color = Color(1.0, 0.60, 0.15, 1.0)
		var plasma_orb: Color = Color(0.52, 0.84, 1.0, 1.0)
		_orb_mat.set_shader_parameter("orb_color", warm_orb.lerp(plasma_orb, overheat))
		_orb_mat.set_shader_parameter("orb_intensity", lerpf(2.2, 3.4, overheat))
		_orb_mat.set_shader_parameter("orb_alpha", 0.74 * fade_val)

	if _flame_proc != null:
		var warm_p: Color = Color(2.2, 1.15, 0.35, 0.85)
		var hot_p: Color = Color(1.75, 2.05, 2.85, 0.90)
		_flame_proc.color = warm_p.lerp(hot_p, overheat * 0.65)


func _update_cone_transforms(eff_len: float, eff_width: float, orb_scale_mult: float, overheat: float) -> void:
	var target_pt: Vector3 = _aim_origin + _aim_dir * _cone_length
	var jet_vec: Vector3 = target_pt - _hand_pos
	var jet_dir: Vector3 = jet_vec.normalized() if jet_vec.length_squared() > 0.04 else _aim_dir

	var y_ax: Vector3 = -jet_dir
	var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
	var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
	var center: Vector3 = _hand_pos + jet_dir * (eff_len * 0.5)

	var c1: float = cos(_spin_angle)
	var s1: float = sin(_spin_angle)
	var rx1: Vector3 = x_ax * c1 + z_ax * s1
	var rz1: Vector3 = -x_ax * s1 + z_ax * c1
	var b_core: Basis = Basis(rx1 * eff_width, y_ax * eff_len, rz1 * eff_width)

	var c2: float = cos(-_spin_angle * 0.75 + 1.05)
	var s2: float = sin(-_spin_angle * 0.75 + 1.05)
	var rx2: Vector3 = x_ax * c2 + z_ax * s2
	var rz2: Vector3 = -x_ax * s2 + z_ax * c2
	var b_mid: Basis = Basis(rx2 * eff_width, y_ax * eff_len, rz2 * eff_width)

	var c3: float = cos(_spin_angle * 0.52 + 2.25)
	var s3: float = sin(_spin_angle * 0.52 + 2.25)
	var rx3: Vector3 = x_ax * c3 + z_ax * s3
	var rz3: Vector3 = -x_ax * s3 + z_ax * c3
	var b_outer: Basis = Basis(rx3 * eff_width, y_ax * (eff_len * 0.96), rz3 * eff_width)

	if _core_cone != null:
		_core_cone.visible = true
		_core_cone.global_transform = Transform3D(b_core, center)
	if _mid_cone != null:
		_mid_cone.visible = true
		_mid_cone.global_transform = Transform3D(b_mid, center)
	if _outer_cone != null:
		_outer_cone.visible = true
		_outer_cone.global_transform = Transform3D(b_outer, _hand_pos + jet_dir * (eff_len * 0.48))

	if _nozzle_orb != null:
		_nozzle_orb.visible = orb_scale_mult > 0.02
		if _nozzle_orb.visible:
			var pulse_s: float = (0.95 + 0.16 * sin(_spin_angle * 5.0) + overheat * 0.22) * orb_scale_mult
			_nozzle_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * pulse_s), _hand_pos + jet_dir * 0.16)

	if _flame_particles != null:
		_flame_particles.global_position = _hand_pos + jet_dir * 0.22
		var p_up: Vector3 = Vector3.UP if absf(jet_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		_flame_particles.look_at(_flame_particles.global_position + jet_dir, p_up)


func _apply_cone_damage_tick() -> void:
	if attack_component == null:
		return

	attack_component.global_position = _hand_pos
	var cos_cone: float = cos(deg_to_rad(cone_half_angle_deg))
	var cos_melee: float = cos(deg_to_rad(65.0))
	var max_reach: float = _cone_length + 0.55
	var max_reach_sq: float = max_reach * max_reach

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_health <= 0.0:
			continue

		var anchor: Vector3 = _get_mob_anchor_pos(mob)
		var diff: Vector3 = anchor - _aim_origin
		var d_sq: float = diff.length_squared()
		if d_sq > max_reach_sq:
			continue

		if d_sq > 0.04:
			var dist: float = sqrt(d_sq)
			var dir_to: Vector3 = diff / dist
			var align: float = _aim_dir.dot(dir_to)
			var req_cos: float = cos_melee if dist < melee_forgiveness_dist else cos_cone
			if align < req_cos:
				var h_diff: Vector3 = anchor - _hand_pos
				var h_len: float = h_diff.length()
				if h_len > melee_forgiveness_dist or (h_len > 0.05 and _aim_dir.dot(h_diff / h_len) < cos_melee):
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
