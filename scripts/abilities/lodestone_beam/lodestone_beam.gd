extends Node3D

const MAIN_STRANDS: int = 2
const MAIN_SEGMENTS: int = 7
const JITTER_STEP: float = 0.032

static var _unit_cyl: CylinderMesh = null
static var _unit_sph: SphereMesh = null
static var _unit_torus: TorusMesh = null
static var _core_gold_mat: StandardMaterial3D = null
static var _outer_blue_mat: StandardMaterial3D = null
static var _ring_blue_mat: StandardMaterial3D = null
static var _ring_gold_mat: StandardMaterial3D = null
static var _pulse_ring_mat: StandardMaterial3D = null

@export var arc_range: float = 16.0
@export var magnet_half_angle_deg: float = 26.0
@export var base_tick_interval: float = 0.20
@export var min_pull_distance: float = 1.25
@export var max_pull_speed: float = 3.8
@export var max_pull_walk_ratio: float = 0.82

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _main_strands: Array = [[], []]
var _start_orb: MeshInstance3D = null
var _end_orb: MeshInstance3D = null
var _mag_ring_a: MeshInstance3D = null
var _mag_ring_b: MeshInstance3D = null
var _suction_ring: MeshInstance3D = null

var _caster: Node3D = null
var _is_channeling: bool = false
var _is_auth: bool = true
var _tick_accum: float = 0.0
var _effective_tick: float = 0.20
var _jitter_accum: float = JITTER_STEP
var _sfx_accum: float = 0.0
var _ring_phase: float = 0.0
var _pull_radius: float = 8.0

var _hand_pos: Vector3 = Vector3.ZERO
var _aim_origin: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.FORWARD
var _remote_end_pos: Vector3 = Vector3.ZERO
var _locked_target: Node3D = null
var _hitbox_cache: Dictionary = {}


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

	if _unit_torus == null:
		_unit_torus = TorusMesh.new()
		_unit_torus.inner_radius = 0.91
		_unit_torus.outer_radius = 1.0
		_unit_torus.rings = 20
		_unit_torus.ring_segments = 6

	if _core_gold_mat == null:
		_core_gold_mat = StandardMaterial3D.new()
		_core_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_gold_mat.albedo_color = Color(2.85, 2.35, 1.25, 1.0)

	if _outer_blue_mat == null:
		_outer_blue_mat = StandardMaterial3D.new()
		_outer_blue_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outer_blue_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_outer_blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outer_blue_mat.albedo_color = Color(0.42, 1.45, 3.85, 0.84)

	if _ring_blue_mat == null:
		_ring_blue_mat = StandardMaterial3D.new()
		_ring_blue_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_blue_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_blue_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_blue_mat.albedo_color = Color(0.50, 1.65, 3.90, 0.82)

	if _ring_gold_mat == null:
		_ring_gold_mat = StandardMaterial3D.new()
		_ring_gold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_gold_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_gold_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_gold_mat.albedo_color = Color(3.10, 2.15, 0.65, 0.80)

	if _pulse_ring_mat == null:
		_pulse_ring_mat = StandardMaterial3D.new()
		_pulse_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pulse_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pulse_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pulse_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pulse_ring_mat.albedo_color = Color(0.75, 1.85, 3.65, 0.46)


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	var mats: Array[StandardMaterial3D] = [_core_gold_mat, _outer_blue_mat]
	for s: int in range(MAIN_STRANDS):
		var seg_list: Array = []
		for _i: int in range(MAIN_SEGMENTS):
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = _unit_cyl
			mi.material_override = mats[s]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			seg_list.append(mi)
		_main_strands[s] = seg_list

	_start_orb = MeshInstance3D.new()
	_start_orb.mesh = _unit_sph
	_start_orb.material_override = _core_gold_mat
	_start_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_start_orb.visible = false
	add_child(_start_orb)

	_end_orb = MeshInstance3D.new()
	_end_orb.mesh = _unit_sph
	_end_orb.material_override = _core_gold_mat
	_end_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_end_orb.visible = false
	add_child(_end_orb)

	_mag_ring_a = MeshInstance3D.new()
	_mag_ring_a.mesh = _unit_torus
	_mag_ring_a.material_override = _ring_blue_mat
	_mag_ring_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mag_ring_a.visible = false
	add_child(_mag_ring_a)

	_mag_ring_b = MeshInstance3D.new()
	_mag_ring_b.mesh = _unit_torus
	_mag_ring_b.material_override = _ring_gold_mat
	_mag_ring_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mag_ring_b.visible = false
	add_child(_mag_ring_b)

	_suction_ring = MeshInstance3D.new()
	_suction_ring.mesh = _unit_torus
	_suction_ring.material_override = _pulse_ring_mat
	_suction_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_suction_ring.visible = false
	add_child(_suction_ring)


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
		_pull_radius = maxf(2.5, scaling_component.final_impact_radius)

	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.07, base_tick_interval / cast_spd)
	_tick_accum = _effective_tick

	_read_aim_data(aim_data)
	_is_channeling = true
	SpellAudioManager.play_lightning_cast(self, _hand_pos, 1.16, -2.8)
	_step_beam(0.0)


func update_channel(caster: Node3D, delta: float, aim_data: Dictionary) -> void:
	_caster = caster
	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.07, base_tick_interval / cast_spd)
	_read_aim_data(aim_data)
	_step_beam(delta)


func update_remote_aim(aim_point: Vector3, aim_dir: Vector3) -> void:
	_remote_end_pos = aim_point
	if aim_dir.length_squared() > 0.001:
		_aim_dir = aim_dir.normalized()


func stop_channel() -> void:
	_is_channeling = false
	queue_free()


func _process(delta: float) -> void:
	if _is_channeling and not _is_auth:
		if _caster != null and is_instance_valid(_caster):
			var left_hand: Node3D = _caster.find_child("MainGauche", true, false) as Node3D
			_hand_pos = left_hand.global_position if left_hand != null else (_caster.global_position + Vector3(0.0, 1.25, 0.0))
			_aim_origin = _hand_pos
		_step_beam(delta)


func _physics_process(delta: float) -> void:
	if not _is_channeling or not _is_auth:
		return
	if _locked_target == null or _is_mob_dead(_locked_target):
		return

	var magnet_pos: Vector3 = _locked_target.global_position
	var max_r: float = _pull_radius

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var neighbor: Node3D = node as Node3D
		if neighbor == null or neighbor == _locked_target or _is_mob_dead(neighbor):
			continue

		var dist_3d: float = neighbor.global_position.distance_to(magnet_pos)
		if dist_3d < min_pull_distance or dist_3d > max_r:
			continue

		var flat_diff: Vector3 = Vector3(
			magnet_pos.x - neighbor.global_position.x,
			0.0,
			magnet_pos.z - neighbor.global_position.z
		)
		var horiz_len: float = flat_diff.length()
		if horiz_len < 0.05:
			continue

		var horiz_dir_to_magnet: Vector3 = flat_diff / horiz_len
		var raw_spd: Variant = neighbor.get("base_movement_speed")
		var base_spd: float = float(raw_spd) if (raw_spd is float or raw_spd is int) else 4.5
		if base_spd <= 0.1:
			base_spd = 4.5

		# Forte aspiration magnétique (~82% de leur vitesse de marche max, plafonnée à 3.8 m/s) sans aucun dégât de zone
		var pull_spd: float = minf(max_pull_speed, base_spd * max_pull_walk_ratio)
		var kc: KnockbackComponent = neighbor.get_node_or_null("knockback_componant") as KnockbackComponent
		if kc == null:
			kc = neighbor.get_node_or_null("KnockbackComponent") as KnockbackComponent
		if kc != null:
			kc.apply_pull_displacement(horiz_dir_to_magnet * (pull_spd * delta))


func _read_aim_data(aim_data: Dictionary) -> void:
	_hand_pos = aim_data.get("hand_pos", _caster.global_position + Vector3(0.0, 1.25, 0.0)) as Vector3
	_aim_origin = aim_data.get("aim_origin", _hand_pos) as Vector3
	var d: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
	_aim_dir = d.normalized() if d.length_squared() > 0.001 else Vector3.FORWARD
	_remote_end_pos = aim_data.get("aim_point", _aim_origin + _aim_dir * 8.0) as Vector3


func _step_beam(delta: float) -> void:
	if not _is_channeling or _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	_ring_phase += delta
	_locked_target = _find_magnetized_enemy()
	var has_target: bool = (_locked_target != null)
	var end_pos: Vector3

	if has_target:
		end_pos = EnchantLightningLink.get_body_anchor_pos(_locked_target)
		_update_magnetic_rings(end_pos, _locked_target.global_position.y)
	else:
		var raw_dist: float = _aim_origin.distance_to(_remote_end_pos)
		var idle_reach: float = minf(7.5, maxf(2.0, raw_dist))
		end_pos = _aim_origin + _aim_dir * idle_reach
		_mag_ring_a.visible = false
		_mag_ring_b.visible = false
		_suction_ring.visible = false

	_sfx_accum += delta
	if _sfx_accum >= 0.34:
		_sfx_accum = 0.0
		var pitch: float = 1.14 if has_target else 1.36
		SpellAudioManager.play_lightning_cast(self, end_pos, pitch, -4.8)

	if _is_auth and has_target:
		_tick_accum += delta
		if _tick_accum >= _effective_tick:
			_tick_accum = fmod(_tick_accum, _effective_tick)
			_apply_single_target_tick(_locked_target)

	_jitter_accum += delta
	if _jitter_accum >= JITTER_STEP:
		_jitter_accum = 0.0
		_rebuild_main_beam(_hand_pos, end_pos, has_target)


func _update_magnetic_rings(center_pos: Vector3, ground_y: float) -> void:
	var ring_scale_a: float = 0.98 + 0.09 * sin(_ring_phase * 8.0)
	var ring_scale_b: float = 1.18 + 0.09 * cos(_ring_phase * 6.6)

	var basis_a: Basis = Basis.IDENTITY
	basis_a = basis_a.rotated(Vector3.RIGHT, 0.46 * sin(_ring_phase * 2.7))
	basis_a = basis_a.rotated(Vector3.UP, _ring_phase * 4.8)
	basis_a = basis_a.scaled(Vector3(ring_scale_a, ring_scale_a * 0.85, ring_scale_a))
	_mag_ring_a.visible = true
	_mag_ring_a.global_transform = Transform3D(basis_a, center_pos)

	var basis_b: Basis = Basis.IDENTITY
	basis_b = basis_b.rotated(Vector3.FORWARD, 0.60 + 0.34 * cos(_ring_phase * 3.1))
	basis_b = basis_b.rotated(Vector3.UP, -_ring_phase * 4.1)
	basis_b = basis_b.scaled(Vector3(ring_scale_b, ring_scale_b * 0.85, ring_scale_b))
	_mag_ring_b.visible = true
	_mag_ring_b.global_transform = Transform3D(basis_b, center_pos)

	# Onde magnétique concentrique se contractant vers la cible pour matérialiser l'attraction
	var pulse_u: float = fmod(_ring_phase * 1.65, 1.0)
	var outer_vis_r: float = minf(4.2, _pull_radius * 0.52)
	var cur_r: float = lerpf(outer_vis_r, 0.65, pulse_u)
	var basis_s: Basis = Basis.IDENTITY.rotated(Vector3.UP, -_ring_phase * 2.2).scaled(Vector3(cur_r, 0.45, cur_r))
	_suction_ring.visible = true
	_suction_ring.global_transform = Transform3D(basis_s, Vector3(center_pos.x, ground_y + 0.25, center_pos.z))


func _find_magnetized_enemy() -> Node3D:
	var best_mob: Node3D = null
	var best_dot: float = cos(deg_to_rad(magnet_half_angle_deg))
	var max_r_sq: float = arc_range * arc_range

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or _is_mob_dead(mob):
			continue

		var anchor: Vector3 = EnchantLightningLink.get_body_anchor_pos(mob)
		var diff: Vector3 = anchor - _aim_origin
		var d_sq: float = diff.length_squared()
		if d_sq > max_r_sq or d_sq < 0.02:
			continue

		var dist: float = sqrt(d_sq)
		var dir_to: Vector3 = diff / dist
		var align: float = _aim_dir.dot(dir_to)
		var eff_align: float = align + (0.08 if dist < 2.5 else 0.0)
		if eff_align >= best_dot:
			best_dot = eff_align
			best_mob = mob

	return best_mob


func _apply_single_target_tick(primary: Node3D) -> void:
	if attack_component == null or primary == null or _is_mob_dead(primary):
		return

	var primary_hb: HitboxComponent = _resolve_hitbox(primary)
	if primary_hb != null:
		attack_component.global_position = _hand_pos
		primary_hb.receive_hit(attack_component)


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


func _rebuild_main_beam(start_pt: Vector3, end_pt: Vector3, locked: bool) -> void:
	var dist: float = start_pt.distance_to(end_pt)
	if dist < 0.08:
		return

	var base_thick: float = 0.052 if locked else 0.028
	var spread: float = 0.24 if locked else 0.35
	var orb_s: float = base_thick * 2.35

	_start_orb.visible = true
	_start_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * orb_s), start_pt)
	_end_orb.visible = locked
	if locked:
		_end_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (orb_s * 1.55)), end_pt)

	var dir: Vector3 = (end_pt - start_pt) / dist
	var seg_len: float = dist / float(MAIN_SEGMENTS)

	for s: int in range(MAIN_STRANDS):
		var segs: Array = _main_strands[s]
		var pts: PackedVector3Array = PackedVector3Array()
		pts.resize(MAIN_SEGMENTS + 1)
		pts[0] = start_pt
		pts[MAIN_SEGMENTS] = end_pt

		var s_thick: float = base_thick * (1.0 if s == 0 else 1.72)
		for j: int in range(1, MAIN_SEGMENTS):
			var mid: Vector3 = start_pt + dir * (seg_len * float(j))
			var arch: float = sin((float(j) / float(MAIN_SEGMENTS)) * PI)
			var jitter: Vector3 = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.85, 0.85),
				randf_range(-1.0, 1.0)
			)
			if jitter.length_squared() > 0.001:
				jitter = jitter.normalized() * randf_range(0.2, 1.0) * spread * (0.3 + 0.7 * arch)
			pts[j] = mid + jitter

		for j: int in range(MAIN_SEGMENTS):
			var p1: Vector3 = pts[j]
			var p2: Vector3 = pts[j + 1]
			var d_seg: Vector3 = p2 - p1
			var d_len: float = d_seg.length()
			var mi: MeshInstance3D = segs[j] as MeshInstance3D
			if mi == null:
				continue
			if d_len < 0.002:
				mi.visible = false
				continue
			mi.visible = true
			var y_ax: Vector3 = d_seg / d_len
			var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
			var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
			var b: Basis = Basis(x_ax * s_thick, y_ax * d_len, z_ax * s_thick)
			mi.global_transform = Transform3D(b, p1.lerp(p2, 0.5))
