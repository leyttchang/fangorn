extends Node3D

enum Phase { DASHING, AIR_BOUNCE, LINGER_OUT }

const STREAK_SEGMENTS: int = 7
const AURA_ARCS: int = 3
const AURA_SEGMENTS: int = 4
const JITTER_STEP: float = 0.028

static var _unit_cyl: CylinderMesh = null
static var _unit_sph: SphereMesh = null
static var _mat_core: StandardMaterial3D = null
static var _mat_glow: StandardMaterial3D = null
static var _mat_aura: StandardMaterial3D = null

@export var dash_speed: float = 38.0
@export var dash_duration: float = 0.22
@export var max_rebounds: int = 4
@export var bounce_rise_duration: float = 0.18
@export var bounce_peak_height: float = 4.2
@export var bounce_hover_duration: float = 1.15
@export var bounce_glide_fall_speed: float = 1.1
@export var linger_duration: float = 0.22

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster_body: CharacterBody3D = null
var _health_comp: HealthComponent = null
var _player_hitbox: Area3D = null

var _phase: Phase = Phase.DASHING
var _phase_timer: float = 0.0
var _rebounds_used: int = 0
var _is_auth: bool = true
var _use_floor_snap: bool = false

var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_start_pos: Vector3 = Vector3.ZERO
var _streak_end_pos: Vector3 = Vector3.ZERO
var _prev_player_center: Vector3 = Vector3.ZERO
var _bounce_target_pos: Vector3 = Vector3.ZERO
var _hit_radius: float = 1.95

var _last_bounced_mob: Node3D = null
var _has_left_last_mob_radius: bool = true
var _prev_rmb_pressed: bool = false
var _queued_rebound_click: bool = false

var _saved_collision_layer: int = 2
var _saved_collision_mask: int = 257
var _saved_hitbox_monitorable: bool = true
var _exception_bodies: Array[PhysicsBody3D] = []
var _state_restored: bool = false
var _hitbox_cache: Dictionary = {}

var _jitter_accum: float = JITTER_STEP
var _hover_sfx_accum: float = 0.0
var _impact_flash_timer: float = 0.0
var _impact_flash_pos: Vector3 = Vector3.ZERO

var _core_segs: Array[MeshInstance3D] = []
var _glow_segs: Array[MeshInstance3D] = []
var _aura_arcs: Array = []
var _body_orb: MeshInstance3D = null
var _impact_orb: MeshInstance3D = null


static func _ensure_shared_visuals() -> void:
	if _unit_cyl == null:
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 1.0
		_unit_cyl.bottom_radius = 1.0
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 5
		_unit_cyl.rings = 0
		_unit_cyl.cap_top = false
		_unit_cyl.cap_bottom = false

	if _unit_sph == null:
		_unit_sph = SphereMesh.new()
		_unit_sph.radius = 1.0
		_unit_sph.height = 2.0
		_unit_sph.radial_segments = 6
		_unit_sph.rings = 3

	if _mat_core == null:
		_mat_core = StandardMaterial3D.new()
		_mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_core.albedo_color = Color(2.45, 3.05, 4.45, 1.0)

	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_glow.albedo_color = Color(0.55, 1.65, 3.95, 0.78)

	if _mat_aura == null:
		_mat_aura = StandardMaterial3D.new()
		_mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_aura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_aura.albedo_color = Color(1.15, 2.25, 4.10, 0.85)


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	for _i: int in range(STREAK_SEGMENTS):
		var c_mi: MeshInstance3D = MeshInstance3D.new()
		c_mi.mesh = _unit_cyl
		c_mi.material_override = _mat_core
		c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c_mi.visible = false
		add_child(c_mi)
		_core_segs.append(c_mi)

		var g_mi: MeshInstance3D = MeshInstance3D.new()
		g_mi.mesh = _unit_cyl
		g_mi.material_override = _mat_glow
		g_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g_mi.visible = false
		add_child(g_mi)
		_glow_segs.append(g_mi)

	_aura_arcs.clear()
	for _a: int in range(AURA_ARCS):
		var seg_arr: Array = []
		for _s: int in range(AURA_SEGMENTS):
			var a_mi: MeshInstance3D = MeshInstance3D.new()
			a_mi.mesh = _unit_cyl
			a_mi.material_override = _mat_aura
			a_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			a_mi.visible = false
			add_child(a_mi)
			seg_arr.append(a_mi)
		_aura_arcs.append(seg_arr)

	_body_orb = MeshInstance3D.new()
	_body_orb.mesh = _unit_sph
	_body_orb.material_override = _mat_glow
	_body_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_orb.visible = false
	add_child(_body_orb)

	_impact_orb = MeshInstance3D.new()
	_impact_orb.mesh = _unit_sph
	_impact_orb.material_override = _mat_core
	_impact_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_orb.visible = false
	add_child(_impact_orb)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())

	_dash_start_pos = caster.global_position + Vector3(0.0, 0.85, 0.0)
	_streak_end_pos = _dash_start_pos
	_prev_player_center = caster.global_position + Vector3(0.0, 0.9, 0.0)
	global_position = caster.global_position

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)
		_hit_radius = maxf(1.2, scaling_component.final_impact_radius)

	_caster_body = caster as CharacterBody3D
	_health_comp = caster.get_node_or_null("HealthComponent") as HealthComponent
	_player_hitbox = caster.get_node_or_null("HitboxComponent") as Area3D

	if _caster_body != null and _is_auth:
		_dash_dir = _compute_aim_dash_dir(false)
		_prev_rmb_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

		_caster_body.set("external_motion_override", true)
		_caster_body.set("is_in_transformation", true)
		if _caster_body.has_method("set_first_person_arms_visible"):
			_caster_body.call("set_first_person_arms_visible", false)

		_saved_collision_layer = _caster_body.collision_layer
		_saved_collision_mask = _caster_body.collision_mask
		_caster_body.collision_layer = 0
		_caster_body.collision_mask = _saved_collision_mask & ~256
		_add_enemy_exceptions()

		if _health_comp != null:
			_health_comp.push_intangible()
		if _player_hitbox != null:
			_saved_hitbox_monitorable = _player_hitbox.monitorable
			_player_hitbox.set_deferred("monitorable", false)

	_phase = Phase.DASHING
	_phase_timer = 0.0
	_rebounds_used = 0
	SpellAudioManager.play_lightning_cast(self, _dash_start_pos, 1.34, -1.0)


func _input(event: InputEvent) -> void:
	if not _is_auth or _phase != Phase.AIR_BOUNCE:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_LEFT):
		_queued_rebound_click = true


func _compute_aim_dash_dir(from_rebound: bool) -> Vector3:
	if _caster_body == null:
		_use_floor_snap = false
		return Vector3.FORWARD

	var cam: Camera3D = _caster_body.get_node_or_null("Camera3D") as Camera3D
	var raw_aim: Vector3 = -cam.global_transform.basis.z if cam != null else -_caster_body.global_transform.basis.z
	if raw_aim.length_squared() < 0.001:
		raw_aim = Vector3.FORWARD
	else:
		raw_aim = raw_aim.normalized()

	if not from_rebound and _caster_body.is_on_floor() and absf(raw_aim.y) <= 0.14:
		var flat_aim: Vector3 = Vector3(raw_aim.x, 0.0, raw_aim.z)
		if flat_aim.length_squared() > 0.001:
			_use_floor_snap = true
			return flat_aim.normalized()
		_use_floor_snap = true
		return Vector3.FORWARD

	_use_floor_snap = false
	return raw_aim


func _add_enemy_exceptions() -> void:
	if _caster_body == null or get_tree() == null:
		return
	var cpos: Vector3 = _caster_body.global_position
	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var pb: PhysicsBody3D = node as PhysicsBody3D
		if pb != null and is_instance_valid(pb) and not _exception_bodies.has(pb):
			if pb.global_position.distance_squared_to(cpos) <= 1225.0:
				_caster_body.add_collision_exception_with(pb)
				_exception_bodies.append(pb)
	for boss_node: Node in get_tree().get_nodes_in_group("Boss"):
		var b_pb: PhysicsBody3D = boss_node as PhysicsBody3D
		if b_pb != null and is_instance_valid(b_pb) and not _exception_bodies.has(b_pb):
			_caster_body.add_collision_exception_with(b_pb)
			_exception_bodies.append(b_pb)


func _physics_process(delta: float) -> void:
	_phase_timer += delta
	_jitter_accum += delta

	if _impact_flash_timer > 0.0:
		_impact_flash_timer = maxf(0.0, _impact_flash_timer - delta)
		if _impact_flash_timer <= 0.0:
			_impact_orb.visible = false
		else:
			var f_scale: float = lerpf(0.18, 0.95, _impact_flash_timer / 0.16)
			_impact_orb.visible = true
			_impact_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * f_scale), _impact_flash_pos)

	if not _is_auth:
		_step_remote_visual()
		return

	if _phase == Phase.LINGER_OUT:
		_step_linger()
		return

	if _caster_body == null or not is_instance_valid(_caster_body) or _caster_body.get("is_dead") == true:
		_end_transformation(false)
		return

	_add_enemy_exceptions()
	_refresh_last_mob_clearance()

	var rmb_now: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var rmb_rising: bool = rmb_now and not _prev_rmb_pressed
	_prev_rmb_pressed = rmb_now

	if _phase == Phase.DASHING:
		_step_dashing_auth()
	elif _phase == Phase.AIR_BOUNCE:
		_step_air_bounce_auth(delta, rmb_rising)


func _refresh_last_mob_clearance() -> void:
	if _has_left_last_mob_radius:
		return
	if _last_bounced_mob == null or _is_mob_dead(_last_bounced_mob) or _caster_body == null:
		_has_left_last_mob_radius = true
		return
	var player_c: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	var mob_c: Vector3 = EnchantLightningLink.get_body_anchor_pos(_last_bounced_mob)
	if player_c.distance_to(mob_c) > (_hit_radius + 0.30):
		_has_left_last_mob_radius = true


func _step_dashing_auth() -> void:
	var prev_c: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	if _use_floor_snap and _caster_body.is_on_floor():
		_caster_body.velocity = Vector3(_dash_dir.x * dash_speed, -6.0, _dash_dir.z * dash_speed)
	else:
		_caster_body.velocity = _dash_dir * dash_speed
	_caster_body.move_and_slide()

	var cur_c: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	global_position = _caster_body.global_position
	_streak_end_pos = _caster_body.global_position + Vector3(0.0, 0.85, 0.0)

	var hit_mob: Node3D = _find_collided_enemy(prev_c, cur_c)
	_prev_player_center = cur_c

	if hit_mob != null:
		_on_monster_impact(hit_mob)
		return

	if _jitter_accum >= JITTER_STEP:
		_jitter_accum = 0.0
		_update_streak(_dash_start_pos, _streak_end_pos, 1.0)
		_update_transformation_aura(true)

	if _phase_timer >= dash_duration:
		# Si le dash n'a percuté aucun monstre, le sort s'arrête immédiatement
		_end_transformation(false)


func _step_air_bounce_auth(delta: float, rmb_rising: bool) -> void:
	var total_air_window: float = bounce_rise_duration + bounce_hover_duration
	if _phase_timer >= total_air_window:
		_end_transformation(false)
		return

	if _phase_timer < bounce_rise_duration:
		var rem_rise: float = maxf(0.025, bounce_rise_duration - _phase_timer)
		var to_peak: Vector3 = _bounce_target_pos - _caster_body.global_position
		var vy: float = clampf(to_peak.y / rem_rise, 4.5, 32.0)
		var vx: float = clampf(to_peak.x * 8.5, -15.0, 15.0)
		var vz: float = clampf(to_peak.z * 8.5, -15.0, 15.0)
		_caster_body.velocity = Vector3(vx, vy, vz)
		_caster_body.move_and_slide()
	else:
		_caster_body.velocity = Vector3(0.0, -bounce_glide_fall_speed, 0.0)
		_caster_body.move_and_slide()

	global_position = _caster_body.global_position
	_prev_player_center = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)

	_hover_sfx_accum += delta
	if _hover_sfx_accum >= 0.30:
		_hover_sfx_accum = 0.0
		SpellAudioManager.play_lightning_cast(self, _prev_player_center, 1.44, -5.8)

	if _jitter_accum >= JITTER_STEP:
		_jitter_accum = 0.0
		var streak_fade: float = clampf(1.0 - (_phase_timer / 0.28), 0.0, 1.0)
		if streak_fade > 0.05:
			_update_streak(_dash_start_pos, _streak_end_pos, streak_fade)
		else:
			_hide_streak()
		_update_transformation_aura(true)

	var click_wanted: bool = false
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		if rmb_rising or Input.is_action_just_pressed("r_click") or _queued_rebound_click:
			click_wanted = true

	if click_wanted:
		if _phase_timer < 0.09:
			# Bufferise un clic ultra-précoce pour garantir d'abord l'impulsion au-dessus du monstre
			_queued_rebound_click = true
		else:
			_trigger_rebound_dash()


func _trigger_rebound_dash() -> void:
	_queued_rebound_click = false
	_rebounds_used += 1
	_dash_dir = _compute_aim_dash_dir(true)
	_dash_start_pos = _caster_body.global_position + Vector3(0.0, 0.85, 0.0)
	_streak_end_pos = _dash_start_pos
	_prev_player_center = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	_phase = Phase.DASHING
	_phase_timer = 0.0
	SpellAudioManager.play_lightning_cast(self, _dash_start_pos, 1.38, -1.0)


func _on_monster_impact(mob: Node3D) -> void:
	var mob_anchor: Vector3 = EnchantLightningLink.get_body_anchor_pos(mob)
	var hb: HitboxComponent = _resolve_hitbox(mob)
	if hb != null and attack_component != null:
		attack_component.global_position = _caster_body.global_position
		hb.receive_hit(attack_component)

	SpellAudioManager.play_lightning_strike_thunder(self, mob_anchor, 1.32, -2.5)
	_streak_end_pos = mob_anchor
	_impact_flash_pos = mob_anchor
	_impact_flash_timer = 0.16
	_impact_orb.visible = true
	_impact_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.95), mob_anchor)
	_update_streak(_dash_start_pos, _streak_end_pos, 1.25)

	if _rebounds_used < max_rebounds:
		_last_bounced_mob = mob
		_has_left_last_mob_radius = false
		var peak_y: float = maxf(mob.global_position.y + bounce_peak_height, _caster_body.global_position.y + 1.6)
		_bounce_target_pos = Vector3(mob.global_position.x, peak_y, mob.global_position.z)
		_phase = Phase.AIR_BOUNCE
		_phase_timer = 0.0
		_hover_sfx_accum = 0.0
		_queued_rebound_click = false
	else:
		# Les 4 relances ont toutes touché : bond gracieux final et fin de la transformation
		_end_transformation(true)


func _find_collided_enemy(seg_a: Vector3, seg_b: Vector3) -> Node3D:
	var best_other: Node3D = null
	var best_other_d_sq: float = _hit_radius * _hit_radius
	var allow_same_mob: bool = (_has_left_last_mob_radius and _phase_timer >= 0.06)
	var hit_same: bool = false

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or _is_mob_dead(mob):
			continue

		var anchor: Vector3 = EnchantLightningLink.get_body_anchor_pos(mob)
		var closest_a: Vector3 = Geometry3D.get_closest_point_to_segment(anchor, seg_a, seg_b)
		var d_sq: float = anchor.distance_squared_to(closest_a)

		var low_pt: Vector3 = mob.global_position + Vector3(0.0, 0.45, 0.0)
		var closest_low: Vector3 = Geometry3D.get_closest_point_to_segment(low_pt, seg_a, seg_b)
		var low_d_sq: float = low_pt.distance_squared_to(closest_low)
		if low_d_sq < d_sq:
			d_sq = low_d_sq

		if d_sq > (_hit_radius * _hit_radius):
			continue

		if mob == _last_bounced_mob:
			if allow_same_mob:
				hit_same = true
			continue

		if d_sq <= best_other_d_sq:
			best_other_d_sq = d_sq
			best_other = mob

	if best_other != null:
		return best_other
	if hit_same and _last_bounced_mob != null and not _is_mob_dead(_last_bounced_mob):
		return _last_bounced_mob
	return null


func _end_transformation(with_final_vault: bool) -> void:
	_restore_player_state(not with_final_vault)
	if with_final_vault and _caster_body != null and is_instance_valid(_caster_body) and _is_auth:
		if _caster_body.has_method("apply_air_launch"):
			var flat_dir: Vector3 = Vector3(_dash_dir.x, 0.0, _dash_dir.z)
			if flat_dir.length_squared() > 0.001:
				flat_dir = flat_dir.normalized()
			_caster_body.call("apply_air_launch", Vector3(flat_dir.x * 5.0, 8.5, flat_dir.z * 5.0))

	_hide_aura()
	_phase = Phase.LINGER_OUT
	_phase_timer = 0.0


func _step_linger() -> void:
	var fade_t: float = _phase_timer / maxf(0.05, linger_duration)
	if fade_t >= 1.0:
		queue_free()
		return
	_update_streak(_dash_start_pos, _streak_end_pos, maxf(0.05, 1.0 - fade_t))


func _step_remote_visual() -> void:
	if _caster_body == null or not is_instance_valid(_caster_body) or _phase_timer >= 0.45:
		queue_free()
		return
	global_position = _caster_body.global_position
	var cur_pt: Vector3 = _caster_body.global_position + Vector3(0.0, 0.85, 0.0)
	var fade_mult: float = clampf(1.0 - maxf(0.0, _phase_timer - dash_duration) / 0.23, 0.05, 1.0)
	if _jitter_accum >= JITTER_STEP:
		_jitter_accum = 0.0
		_update_streak(_dash_start_pos, cur_pt, fade_mult)


func _restore_player_state(apply_exit_momentum: bool = true) -> void:
	if _state_restored:
		return
	_state_restored = true

	if _caster_body != null and is_instance_valid(_caster_body) and _is_auth:
		for pb: PhysicsBody3D in _exception_bodies:
			if pb != null and is_instance_valid(pb):
				_caster_body.remove_collision_exception_with(pb)
		_exception_bodies.clear()

		_caster_body.collision_layer = _saved_collision_layer
		_caster_body.collision_mask = _saved_collision_mask
		if apply_exit_momentum:
			_caster_body.velocity = Vector3(_dash_dir.x * 4.5, minf(0.0, _caster_body.velocity.y), _dash_dir.z * 4.5)
		if _caster_body.has_method("set_first_person_arms_visible"):
			_caster_body.call("set_first_person_arms_visible", true)
		_caster_body.set("external_motion_override", false)
		_caster_body.set("is_in_transformation", false)

	if _health_comp != null and is_instance_valid(_health_comp) and _is_auth:
		_health_comp.pop_intangible()

	if _player_hitbox != null and is_instance_valid(_player_hitbox) and _is_auth:
		_player_hitbox.set_deferred("monitorable", _saved_hitbox_monitorable)


func _exit_tree() -> void:
	_restore_player_state(false)


func _resolve_hitbox(mob: Node3D) -> HitboxComponent:
	var mid: int = mob.get_instance_id()
	var cached_val: Variant = _hitbox_cache.get(mid)
	var hb: HitboxComponent = null
	if cached_val != null and is_instance_valid(cached_val):
		hb = cached_val as HitboxComponent
	if hb != null:
		return hb

	hb = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		var found_areas: Array[Node] = mob.find_children("*", "Area3D", true, false)
		for cand: Node in found_areas:
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	if hb != null:
		_hitbox_cache[mid] = hb
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


func _update_transformation_aura(show_aura: bool) -> void:
	if not show_aura or _caster_body == null or not is_instance_valid(_caster_body):
		_hide_aura()
		return

	var body_center: Vector3 = _caster_body.global_position + Vector3(0.0, 0.95, 0.0)
	_body_orb.visible = true
	var pulse_s: float = 0.28 + 0.06 * sin(_phase_timer * 24.0)
	_body_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * pulse_s), body_center)

	var cam: Camera3D = _caster_body.get_node_or_null("Camera3D") as Camera3D
	var ring_origin: Vector3 = body_center
	var right_ax: Vector3 = Vector3.RIGHT
	var up_ax: Vector3 = Vector3.UP
	var ring_radius: float = 0.55
	var seg_thick: float = 0.018

	if cam != null and _is_auth:
		var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized()
		right_ax = cam.global_transform.basis.x.normalized()
		up_ax = cam.global_transform.basis.y.normalized()
		ring_origin = cam.global_position + cam_fwd * 0.62
		ring_radius = 0.42
		seg_thick = 0.0085

	for a_idx: int in range(AURA_ARCS):
		var seg_arr: Array = _aura_arcs[a_idx]
		var base_ang: float = (TAU / float(AURA_ARCS)) * float(a_idx) + _phase_timer * 5.2
		var span_ang: float = 1.05
		var pts: PackedVector3Array = PackedVector3Array()
		pts.resize(AURA_SEGMENTS + 1)

		for j: int in range(AURA_SEGMENTS + 1):
			var t: float = float(j) / float(AURA_SEGMENTS)
			var ang: float = base_ang + (t - 0.5) * span_ang
			var r_jit: float = ring_radius + randf_range(-0.045, 0.045)
			var pt: Vector3 = ring_origin + (right_ax * cos(ang) + up_ax * sin(ang)) * r_jit
			pts[j] = pt

		for j: int in range(AURA_SEGMENTS):
			var p1: Vector3 = pts[j]
			var p2: Vector3 = pts[j + 1]
			var d: Vector3 = p2 - p1
			var l: float = d.length()
			var mi: MeshInstance3D = seg_arr[j] as MeshInstance3D
			if mi == null:
				continue
			if l < 0.002:
				mi.visible = false
				continue
			mi.visible = true
			var y_ax: Vector3 = d / l
			var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
			var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
			mi.global_transform = Transform3D(Basis(x_ax * seg_thick, y_ax * l, z_ax * seg_thick), p1.lerp(p2, 0.5))


func _hide_aura() -> void:
	if _body_orb != null:
		_body_orb.visible = false
	for a_idx: int in range(_aura_arcs.size()):
		var seg_arr: Array = _aura_arcs[a_idx]
		for m_var: Variant in seg_arr:
			var mi: MeshInstance3D = m_var as MeshInstance3D
			if mi != null:
				mi.visible = false


func _hide_streak() -> void:
	for c_mi: MeshInstance3D in _core_segs:
		c_mi.visible = false
	for g_mi: MeshInstance3D in _glow_segs:
		g_mi.visible = false


func _update_streak(p_start: Vector3, p_end: Vector3, width_mult: float) -> void:
	var dist: float = p_start.distance_to(p_end)
	if dist < 0.15:
		_hide_streak()
		return

	var dir: Vector3 = (p_end - p_start) / dist
	var seg_len: float = dist / float(STREAK_SEGMENTS)
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(STREAK_SEGMENTS + 1)
	pts[0] = p_start
	pts[STREAK_SEGMENTS] = p_end

	for i: int in range(1, STREAK_SEGMENTS):
		var base_p: Vector3 = p_start + dir * (seg_len * float(i))
		var arch: float = sin((float(i) / float(STREAK_SEGMENTS)) * PI)
		var rnd: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7), randf_range(-1.0, 1.0))
		if rnd.length_squared() > 0.001:
			rnd = rnd.normalized() * 0.30 * arch * width_mult
		pts[i] = base_p + rnd

	var core_r: float = 0.062 * width_mult
	var glow_r: float = 0.145 * width_mult

	for i: int in range(STREAK_SEGMENTS):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = b - a
		var l: float = d.length()
		var c_mi: MeshInstance3D = _core_segs[i]
		var g_mi: MeshInstance3D = _glow_segs[i]
		if l < 0.002:
			c_mi.visible = false
			g_mi.visible = false
			continue
		c_mi.visible = true
		g_mi.visible = true
		var y_ax: Vector3 = d / l
		var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
		var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
		var mid: Vector3 = a.lerp(b, 0.5)
		c_mi.global_transform = Transform3D(Basis(x_ax * core_r, y_ax * l, z_ax * core_r), mid)
		g_mi.global_transform = Transform3D(Basis(x_ax * glow_r, y_ax * l, z_ax * glow_r), mid)
