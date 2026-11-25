extends Node3D

const MAIN_SEGMENTS: int = 12
const SECONDARY_SEGMENTS: int = 9
const FORK_COUNT: int = 4
const FORK_SEGMENTS: int = 2
const FP_TENDRIL_COUNT: int = 4
const FP_TENDRIL_SEGS: int = 3
const NODE_ORB_COUNT: int = 4
const JITTER_INTERVAL: float = 0.032

const KINK_1_T: float = 0.31
const KINK_2_T: float = 0.69

static var _streak_cyl: CylinderMesh = null
static var _node_sph: SphereMesh = null
static var _streak_mat_core: StandardMaterial3D = null
static var _streak_mat_glow: StandardMaterial3D = null
static var _streak_mat_branch: StandardMaterial3D = null

@export var dash_speed: float = 33.5
@export var dash_duration: float = 0.21
@export var linger_duration: float = 0.50
## Amplitude latérale des cassures anguleuses en zig-zag (revient pile dans l'axe visé à l'arrivée)
@export var zigzag_amplitude: float = 1.12
## Léger boost de FOV pendant la dématérialisation en éclair
@export var fov_boost_deg: float = 8.5

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster_body: CharacterBody3D = null
var _cam: Camera3D = null
var _health_comp: HealthComponent = null
var _player_hitbox: Area3D = null

var _dash_dir: Vector3 = Vector3.FORWARD
var _right_dir: Vector3 = Vector3.RIGHT
var _zig_sign: float = 1.0
var _prev_lat_offset: float = 0.0

var _start_pos: Vector3 = Vector3.ZERO
var _kink_1_pos: Vector3 = Vector3.ZERO
var _kink_2_pos: Vector3 = Vector3.ZERO
var _end_pos: Vector3 = Vector3.ZERO
var _kink_1_locked: bool = false
var _kink_2_locked: bool = false
var _last_kink_stage: int = 0

var _elapsed: float = 0.0
var _jitter_timer: float = JITTER_INTERVAL
var _is_dashing: bool = false
var _is_auth: bool = true

var _saved_collision_layer: int = 2
var _saved_collision_mask: int = 257
var _saved_hitbox_monitorable: bool = true
var _saved_cam_fov: float = 75.0
var _saved_cam_roll: float = 0.0
var _cam_captured: bool = false
var _cam_restored: bool = false
var _exception_bodies: Array[PhysicsBody3D] = []
var _state_restored: bool = false

var _core_segs: Array[MeshInstance3D] = []
var _glow_segs: Array[MeshInstance3D] = []
var _sec_segs: Array[MeshInstance3D] = []
var _fork_segs: Array[MeshInstance3D] = []
var _fp_segs: Array[MeshInstance3D] = []
var _node_orbs: Array[MeshInstance3D] = []

var _cached_main_jitter: PackedVector3Array = PackedVector3Array()
var _cached_sec_jitter: PackedVector3Array = PackedVector3Array()
var _cached_fork_dirs: PackedVector3Array = PackedVector3Array()


static func _ensure_shared_visuals() -> void:
	if _streak_cyl == null:
		_streak_cyl = CylinderMesh.new()
		_streak_cyl.top_radius = 1.0
		_streak_cyl.bottom_radius = 1.0
		_streak_cyl.height = 1.0
		_streak_cyl.radial_segments = 5
		_streak_cyl.rings = 0
		_streak_cyl.cap_top = false
		_streak_cyl.cap_bottom = false

	if _node_sph == null:
		_node_sph = SphereMesh.new()
		_node_sph.radius = 1.0
		_node_sph.height = 2.0
		_node_sph.radial_segments = 6
		_node_sph.rings = 3

	if _streak_mat_core == null:
		_streak_mat_core = StandardMaterial3D.new()
		_streak_mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_mat_core.albedo_color = Color(2.55, 3.15, 4.65, 1.0)

	if _streak_mat_glow == null:
		_streak_mat_glow = StandardMaterial3D.new()
		_streak_mat_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_streak_mat_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_streak_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_mat_glow.albedo_color = Color(0.50, 1.58, 3.95, 0.80)

	if _streak_mat_branch == null:
		_streak_mat_branch = StandardMaterial3D.new()
		_streak_mat_branch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_streak_mat_branch.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_streak_mat_branch.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_mat_branch.albedo_color = Color(1.25, 2.35, 4.25, 0.88)


func _ready() -> void:
	_ensure_shared_visuals()

	for _i: int in range(MAIN_SEGMENTS):
		_core_segs.append(_make_seg_mesh(_streak_cyl, _streak_mat_core))
		_glow_segs.append(_make_seg_mesh(_streak_cyl, _streak_mat_glow))

	for _i: int in range(SECONDARY_SEGMENTS):
		_sec_segs.append(_make_seg_mesh(_streak_cyl, _streak_mat_branch))

	for _i: int in range(FORK_COUNT * FORK_SEGMENTS):
		_fork_segs.append(_make_seg_mesh(_streak_cyl, _streak_mat_branch))

	for _i: int in range(FP_TENDRIL_COUNT * FP_TENDRIL_SEGS):
		_fp_segs.append(_make_seg_mesh(_streak_cyl, _streak_mat_core))

	for _i: int in range(NODE_ORB_COUNT):
		_node_orbs.append(_make_seg_mesh(_node_sph, _streak_mat_core))

	_cached_main_jitter.resize(MAIN_SEGMENTS + 1)
	_cached_sec_jitter.resize(SECONDARY_SEGMENTS + 1)
	_cached_fork_dirs.resize(FORK_COUNT * FORK_SEGMENTS)
	_reroll_electric_jitter()


func _make_seg_mesh(mesh_res: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	_is_auth = (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())
	_zig_sign = 1.0 if randf() < 0.5 else -1.0
	_start_pos = caster.global_position + Vector3(0.0, 0.90, 0.0)
	_kink_1_pos = _start_pos
	_kink_2_pos = _start_pos
	_end_pos = _start_pos
	global_position = caster.global_position

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)

	_caster_body = caster as CharacterBody3D
	_health_comp = caster.get_node_or_null("HealthComponent") as HealthComponent
	_player_hitbox = caster.get_node_or_null("HitboxComponent") as Area3D

	if _caster_body != null:
		_cam = _caster_body.get_node_or_null("Camera3D") as Camera3D
		var raw_aim: Vector3 = -_cam.global_transform.basis.z if _cam != null else -_caster_body.global_transform.basis.z
		var flat_aim := Vector3(raw_aim.x, 0.0, raw_aim.z)
		if flat_aim.length_squared() > 0.001:
			flat_aim = flat_aim.normalized()
		else:
			flat_aim = Vector3.FORWARD

		if raw_aim.y > 0.10 or not _caster_body.is_on_floor():
			var clamped_y: float = clampf(raw_aim.y, -0.45, 0.45)
			_dash_dir = Vector3(flat_aim.x, clamped_y, flat_aim.z).normalized()
		else:
			_dash_dir = flat_aim

		var right_raw: Vector3 = flat_aim.cross(Vector3.UP)
		_right_dir = right_raw.normalized() if right_raw.length_squared() > 0.001 else Vector3.RIGHT

	if _caster_body != null and _is_auth:
		if _cam != null and _cam.current:
			_saved_cam_fov = _cam.fov
			_saved_cam_roll = _cam.rotation.z
			_cam_captured = true

		_caster_body.set("external_motion_override", true)
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

	_is_dashing = true
	SpellAudioManager.play_lightning_cast(self, _start_pos, 1.38, -1.0)


func _compute_zigzag_lateral_offset(u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	var peak_1: float = _zig_sign * zigzag_amplitude
	var peak_2: float = -_zig_sign * zigzag_amplitude * 0.92
	if t <= KINK_1_T:
		return lerpf(0.0, peak_1, t / KINK_1_T)
	elif t <= KINK_2_T:
		return lerpf(peak_1, peak_2, (t - KINK_1_T) / (KINK_2_T - KINK_1_T))
	else:
		return lerpf(peak_2, 0.0, (t - KINK_2_T) / (1.0 - KINK_2_T))


func _clamp_lateral_step_against_walls(origin_world: Vector3, desired_lat_step: float) -> float:
	if absf(desired_lat_step) <= 0.001 or _caster_body == null or not is_inside_tree() or get_world_3d() == null:
		return desired_lat_step
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return desired_lat_step
	var side_dir: Vector3 = _right_dir * signf(desired_lat_step)
	var probe_dist: float = absf(desired_lat_step) + 0.55
	var ray_from: Vector3 = origin_world + Vector3(0.0, 0.95, 0.0)
	var ray_to: Vector3 = ray_from + side_dir * probe_dist
	var q := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 129) # Sol/murs (1) + arbres (128)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty() and hit.has("position"):
		var hit_p: Vector3 = hit["position"] as Vector3
		var free_dist: float = maxf(0.0, ray_from.distance_to(hit_p) - 0.55)
		return signf(desired_lat_step) * minf(absf(desired_lat_step), free_dist)
	return desired_lat_step


func _add_enemy_exceptions() -> void:
	if _caster_body == null or get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var pb: PhysicsBody3D = node as PhysicsBody3D
		if pb != null and is_instance_valid(pb) and not _exception_bodies.has(pb):
			_caster_body.add_collision_exception_with(pb)
			_exception_bodies.append(pb)
	for boss_node: Node in get_tree().get_nodes_in_group("Boss"):
		var b_pb: PhysicsBody3D = boss_node as PhysicsBody3D
		if b_pb != null and is_instance_valid(b_pb) and not _exception_bodies.has(b_pb):
			_caster_body.add_collision_exception_with(b_pb)
			_exception_bodies.append(b_pb)


func _physics_process(delta: float) -> void:
	var prev_elapsed: float = _elapsed
	_elapsed += delta
	_jitter_timer += delta
	if _jitter_timer >= JITTER_INTERVAL:
		_jitter_timer = 0.0
		_reroll_electric_jitter()

	if _is_dashing:
		if _caster_body != null and is_instance_valid(_caster_body):
			var u_prev: float = clampf(prev_elapsed / maxf(0.05, dash_duration), 0.0, 1.0)
			var u_curr: float = clampf(_elapsed / maxf(0.05, dash_duration), 0.0, 1.0)

			if _is_auth:
				if _elapsed < dash_duration and _caster_body.get("is_dead") != true:
					_add_enemy_exceptions()
					var target_lat: float = _compute_zigzag_lateral_offset(u_curr)
					var raw_lat_delta: float = target_lat - _prev_lat_offset
					var safe_lat_delta: float = _clamp_lateral_step_against_walls(_caster_body.global_position, raw_lat_delta)
					_prev_lat_offset += safe_lat_delta

					var lat_vel: Vector3 = _right_dir * (safe_lat_delta / maxf(0.001, delta))
					var fwd_vel: Vector3 = _dash_dir * dash_speed
					if _dash_dir.y == 0.0 and _caster_body.is_on_floor():
						_caster_body.velocity = Vector3(fwd_vel.x + lat_vel.x, -6.0, fwd_vel.z + lat_vel.z)
					else:
						_caster_body.velocity = fwd_vel + lat_vel
					_caster_body.move_and_slide()

					_update_first_person_camera_snap(u_curr, delta)
				else:
					# Aligne proprement la dernière fraction de zig-zag à la sortie du dash
					if u_prev < 1.0 and _caster_body.get("is_dead") != true:
						var final_lat_delta: float = _clamp_lateral_step_against_walls(_caster_body.global_position, -_prev_lat_offset)
						if absf(final_lat_delta) > 0.005:
							_caster_body.move_and_collide(_right_dir * final_lat_delta)
						_prev_lat_offset = 0.0
					_finish_dash()

			var cur_anchor: Vector3 = _caster_body.global_position + Vector3(0.0, 0.90, 0.0)
			if not _kink_1_locked and u_curr >= KINK_1_T:
				_kink_1_locked = true
				_kink_1_pos = cur_anchor
			elif not _kink_1_locked:
				_kink_1_pos = _start_pos.lerp(cur_anchor, 0.5)

			if not _kink_2_locked and u_curr >= KINK_2_T:
				_kink_2_locked = true
				_kink_2_pos = cur_anchor
			elif not _kink_2_locked:
				_kink_2_pos = _kink_1_pos.lerp(cur_anchor, 0.5)

			_end_pos = cur_anchor
			global_position = _caster_body.global_position

			_update_electric_trail(u_curr, 1.0)
			_update_fp_tendrils(u_curr)

			if not _is_auth and _elapsed >= dash_duration:
				_is_dashing = false
				_hide_fp_tendrils()
		else:
			_finish_dash()
	else:
		_hide_fp_tendrils()
		var post_t: float = _elapsed - dash_duration
		if _cam_captured and not _cam_restored and _cam != null and is_instance_valid(_cam):
			var recover_a: float = clampf(post_t / 0.10, 0.0, 1.0)
			_cam.fov = lerpf(_saved_cam_fov + fov_boost_deg * 0.5, _saved_cam_fov, recover_a)
			_cam.rotation.z = lerpf(_cam.rotation.z, _saved_cam_roll, recover_a)
			if recover_a >= 1.0:
				_cam.fov = _saved_cam_fov
				_cam.rotation.z = _saved_cam_roll
				_cam_restored = true

		var fade_t: float = post_t / maxf(0.05, linger_duration)
		if fade_t >= 1.0:
			queue_free()
			return
		var width_mult: float = pow(maxf(0.03, 1.0 - fade_t), 0.72)
		_update_electric_trail(1.0, width_mult)


func _update_first_person_camera_snap(u: float, delta: float) -> void:
	var stage: int = 0 if u < KINK_1_T else (1 if u < KINK_2_T else 2)
	if stage != _last_kink_stage:
		_last_kink_stage = stage
		_reroll_electric_jitter()
		if _caster_body != null:
			SpellAudioManager.play_lightning_cast(self, _caster_body.global_position + Vector3(0.0, 1.0, 0.0), 1.62 + float(stage) * 0.12, -6.5)

	if not _cam_captured or _cam == null or not is_instance_valid(_cam):
		return

	var fov_env: float = sin(clampf(u, 0.0, 1.0) * PI)
	_cam.fov = _saved_cam_fov + fov_boost_deg * (0.35 + 0.65 * fov_env)

	# Micro-roulis électrique sec à chaque segment du zig-zag (~2.1° max, jamais nauséeux)
	var seg_sign: float = _zig_sign if stage == 0 else (-_zig_sign if stage == 1 else _zig_sign * 0.45)
	var target_roll: float = _saved_cam_roll - deg_to_rad(2.15) * seg_sign * (1.0 - u * 0.35)
	_cam.rotation.z = lerpf(_cam.rotation.z, target_roll, minf(1.0, 26.0 * delta))


func _finish_dash() -> void:
	if not _is_dashing:
		return
	_is_dashing = false
	_hide_fp_tendrils()
	_restore_player_state()
	if attack_component != null and is_instance_valid(attack_component):
		attack_component.set_deferred("monitoring", false)


func _restore_player_state() -> void:
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
		_caster_body.velocity = Vector3(_dash_dir.x * 4.8, minf(0.0, _caster_body.velocity.y), _dash_dir.z * 4.8)
		_caster_body.set("external_motion_override", false)

	if _health_comp != null and is_instance_valid(_health_comp) and _is_auth:
		_health_comp.pop_intangible()

	if _player_hitbox != null and is_instance_valid(_player_hitbox) and _is_auth:
		_player_hitbox.set_deferred("monitorable", _saved_hitbox_monitorable)


func _hard_restore_camera() -> void:
	if _cam_captured and not _cam_restored and _cam != null and is_instance_valid(_cam):
		_cam.fov = _saved_cam_fov
		_cam.rotation.z = _saved_cam_roll
		_cam_restored = true


func _exit_tree() -> void:
	_restore_player_state()
	_hard_restore_camera()


func _reroll_electric_jitter() -> void:
	for i: int in range(MAIN_SEGMENTS + 1):
		if i == 0 or i == MAIN_SEGMENTS:
			_cached_main_jitter[i] = Vector3.ZERO
		else:
			_cached_main_jitter[i] = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.65, 0.65),
				randf_range(-1.0, 1.0)
			)

	for i: int in range(SECONDARY_SEGMENTS + 1):
		if i == 0 or i == SECONDARY_SEGMENTS:
			_cached_sec_jitter[i] = Vector3.ZERO
		else:
			_cached_sec_jitter[i] = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.75, 0.75),
				randf_range(-1.0, 1.0)
			)

	for i: int in range(FORK_COUNT * FORK_SEGMENTS):
		var v := Vector3(randf_range(-1.0, 1.0), randf_range(-0.55, 0.75), randf_range(-1.0, 1.0))
		_cached_fork_dirs[i] = v.normalized() if v.length_squared() > 0.001 else Vector3.UP


func _sample_zigzag_spine(s: float, u_progress: float) -> Vector3:
	# Reconstruit la colonne vertébrale anguleuse à 3 brins derrière le joueur (_start_pos -> _kink_1 -> _kink_2 -> _end_pos)
	if not _kink_1_locked:
		return _start_pos.lerp(_end_pos, s)
	if not _kink_2_locked:
		var split_a: float = clampf(KINK_1_T / maxf(KINK_1_T + 0.01, u_progress), 0.25, 0.85)
		if s <= split_a:
			return _start_pos.lerp(_kink_1_pos, s / split_a)
		return _kink_1_pos.lerp(_end_pos, (s - split_a) / maxf(0.01, 1.0 - split_a))

	if s <= KINK_1_T:
		return _start_pos.lerp(_kink_1_pos, s / KINK_1_T)
	elif s <= KINK_2_T:
		return _kink_1_pos.lerp(_kink_2_pos, (s - KINK_1_T) / (KINK_2_T - KINK_1_T))
	else:
		return _kink_2_pos.lerp(_end_pos, (s - KINK_2_T) / (1.0 - KINK_2_T))


func _update_electric_trail(u_progress: float, width_mult: float) -> void:
	var total_span: float = _start_pos.distance_to(_end_pos)
	if total_span < 0.12:
		return

	# 1. Arc électrique principal en zig-zag (coeur blanc-cyan + halo bleu électrique)
	var main_pts := PackedVector3Array()
	main_pts.resize(MAIN_SEGMENTS + 1)
	for i: int in range(MAIN_SEGMENTS + 1):
		var s: float = float(i) / float(MAIN_SEGMENTS)
		var base_p: Vector3 = _sample_zigzag_spine(s, u_progress)
		# Préserve les angles vifs aux cassures KINK_1_T (i=4) et KINK_2_T (i=8) tout en crépitant entre elles
		var corner_pin: float = 0.25 if (i == 4 or i == 8) else 1.0
		var jit: Vector3 = _cached_main_jitter[i] * (0.20 * corner_pin * width_mult)
		main_pts[i] = base_p + jit

	var core_r: float = 0.068 * width_mult
	var glow_r: float = 0.175 * width_mult
	for i: int in range(MAIN_SEGMENTS):
		_place_cylinder_between(_core_segs[i], main_pts[i], main_pts[i + 1], core_r)
		_place_cylinder_between(_glow_segs[i], main_pts[i], main_pts[i + 1], glow_r)

	# 2. Second arc tressé nerveux qui s'enroule et claque autour de la trace principale
	var sec_pts := PackedVector3Array()
	sec_pts.resize(SECONDARY_SEGMENTS + 1)
	for i: int in range(SECONDARY_SEGMENTS + 1):
		var s: float = float(i) / float(SECONDARY_SEGMENTS)
		var base_p: Vector3 = _sample_zigzag_spine(s, u_progress)
		var jit_s: Vector3 = _cached_sec_jitter[i] * (0.42 * width_mult)
		sec_pts[i] = base_p + jit_s

	var sec_r: float = 0.042 * width_mult
	for i: int in range(SECONDARY_SEGMENTS):
		_place_cylinder_between(_sec_segs[i], sec_pts[i], sec_pts[i + 1], sec_r)

	# 3. Éclairs fourchus jaillissant des sommets anguleux du zig-zag derrière le joueur
	var fork_origins: Array[Vector3] = [
		_start_pos,
		_kink_1_pos if _kink_1_locked else _start_pos.lerp(_end_pos, 0.35),
		_kink_2_pos if _kink_2_locked else _start_pos.lerp(_end_pos, 0.70),
		_end_pos.lerp(_kink_2_pos if _kink_2_locked else _start_pos, 0.18)
	]
	var fork_r: float = 0.032 * width_mult
	for f: int in range(FORK_COUNT):
		var p_a: Vector3 = fork_origins[f]
		var d0: Vector3 = (_cached_fork_dirs[f * 2] + _right_dir * (0.65 if f % 2 == 0 else -0.65)).normalized()
		var p_b: Vector3 = p_a + d0 * (0.68 * width_mult)
		var d1: Vector3 = (_cached_fork_dirs[f * 2 + 1] + d0 * 0.75).normalized()
		var p_c: Vector3 = p_b + d1 * (0.55 * width_mult)
		_place_cylinder_between(_fork_segs[f * 2], p_a, p_b, fork_r)
		_place_cylinder_between(_fork_segs[f * 2 + 1], p_b, p_c, fork_r * 0.65)

	# 4. Nœuds de plasma lumineux aux points de cassure du zig-zag
	var orb_positions: Array[Vector3] = [_start_pos, fork_origins[1], fork_origins[2], _end_pos]
	var orb_r: float = 0.135 * width_mult
	for idx: int in range(NODE_ORB_COUNT):
		var orb: MeshInstance3D = _node_orbs[idx]
		orb.visible = width_mult > 0.06
		var s_val: float = orb_r * (1.25 if (idx == 1 or idx == 2) else 0.95)
		orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s_val), orb_positions[idx])


func _update_fp_tendrils(u_progress: float) -> void:
	if not _is_auth or _cam == null or not is_instance_valid(_cam) or not _cam.current:
		_hide_fp_tendrils()
		return

	var cam_xf: Transform3D = _cam.global_transform
	var fwd: Vector3 = -cam_xf.basis.z
	var rgt: Vector3 = cam_xf.basis.x
	var upv: Vector3 = cam_xf.basis.y
	var env: float = 0.55 + 0.45 * sin(clampf(u_progress, 0.0, 1.0) * PI)

	var offsets: Array[Vector2] = [
		Vector2(-0.46, -0.24),
		Vector2(0.46, -0.24),
		Vector2(-0.52, 0.22),
		Vector2(0.52, 0.22)
	]

	for t_idx: int in range(FP_TENDRIL_COUNT):
		var off: Vector2 = offsets[t_idx]
		var p0: Vector3 = cam_xf.origin + fwd * 0.52 + rgt * off.x + upv * off.y
		var p_end: Vector3 = cam_xf.origin + fwd * 1.35 + rgt * (off.x * 0.42) + upv * (off.y * 0.38)
		var prev_p: Vector3 = p0
		for s_idx: int in range(FP_TENDRIL_SEGS):
			var frac: float = float(s_idx + 1) / float(FP_TENDRIL_SEGS)
			var next_p: Vector3 = p0.lerp(p_end, frac)
			if s_idx < FP_TENDRIL_SEGS - 1:
				var j: Vector3 = _cached_main_jitter[(t_idx * 3 + s_idx + 1) % MAIN_SEGMENTS]
				next_p += (rgt * j.x + upv * j.y) * 0.085
			var seg_mi: MeshInstance3D = _fp_segs[t_idx * FP_TENDRIL_SEGS + s_idx]
			_place_cylinder_between(seg_mi, prev_p, next_p, 0.0085 * env)
			prev_p = next_p


func _hide_fp_tendrils() -> void:
	for mi: MeshInstance3D in _fp_segs:
		if mi != null and mi.visible:
			mi.visible = false


func _place_cylinder_between(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.003 or radius <= 0.0005:
		mi.visible = false
		return
	mi.visible = true
	var y_ax: Vector3 = d / l
	var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
	var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
	var mid: Vector3 = a.lerp(b, 0.5)
	mi.global_transform = Transform3D(Basis(x_ax * radius, y_ax * l, z_ax * radius), mid)
