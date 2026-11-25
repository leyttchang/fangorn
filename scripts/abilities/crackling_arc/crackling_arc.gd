extends Node3D

const STRAND_COUNT: int = 2
const SEGMENTS: int = 7
const JITTER_STEP: float = 0.032

static var _unit_cyl: CylinderMesh = null
static var _unit_sph: SphereMesh = null
static var _core_mat: StandardMaterial3D = null
static var _outer_mat: StandardMaterial3D = null

@export var arc_range: float = 13.5
@export var magnet_half_angle_deg: float = 26.0
@export var base_tick_interval: float = 0.20

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _strands: Array = [[], []]
var _start_orb: MeshInstance3D = null
var _end_orb: MeshInstance3D = null

var _caster: Node3D = null
var _is_channeling: bool = false
var _is_auth: bool = true
var _tick_accum: float = 0.0
var _effective_tick: float = 0.20
var _jitter_accum: float = JITTER_STEP
var _sfx_accum: float = 0.0

var _hand_pos: Vector3 = Vector3.ZERO
var _aim_origin: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.FORWARD
var _remote_end_pos: Vector3 = Vector3.ZERO
var _locked_target: Node3D = null
var _hitbox_cache: Dictionary = {} # mob_instance_id -> HitboxComponent


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

	if _core_mat == null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = Color(1.85, 2.55, 3.85, 1.0)

	if _outer_mat == null:
		_outer_mat = StandardMaterial3D.new()
		_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outer_mat.albedo_color = Color(0.45, 1.25, 3.25, 0.78)


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	var mats: Array[StandardMaterial3D] = [_core_mat, _outer_mat]
	for s: int in range(STRAND_COUNT):
		var seg_list: Array = []
		for _i: int in range(SEGMENTS):
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = _unit_cyl
			mi.material_override = mats[s]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			seg_list.append(mi)
		_strands[s] = seg_list

	_start_orb = MeshInstance3D.new()
	_start_orb.mesh = _unit_sph
	_start_orb.material_override = _core_mat
	_start_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_start_orb.visible = false
	add_child(_start_orb)

	_end_orb = MeshInstance3D.new()
	_end_orb.mesh = _unit_sph
	_end_orb.material_override = _core_mat
	_end_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_end_orb.visible = false
	add_child(_end_orb)


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

	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.07, base_tick_interval / cast_spd)
	_tick_accum = _effective_tick

	_read_aim_data(aim_data)
	_is_channeling = true
	SpellAudioManager.play_lightning_cast(self, _hand_pos, 1.24, -3.5)
	_step_arc(0.0)


func update_channel(caster: Node3D, delta: float, aim_data: Dictionary) -> void:
	_caster = caster
	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick = maxf(0.07, base_tick_interval / cast_spd)
	_read_aim_data(aim_data)
	_step_arc(delta)


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
		_step_arc(delta)


func _read_aim_data(aim_data: Dictionary) -> void:
	_hand_pos = aim_data.get("hand_pos", _caster.global_position + Vector3(0.0, 1.25, 0.0)) as Vector3
	_aim_origin = aim_data.get("aim_origin", _hand_pos) as Vector3
	var d: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
	_aim_dir = d.normalized() if d.length_squared() > 0.001 else Vector3.FORWARD
	_remote_end_pos = aim_data.get("aim_point", _aim_origin + _aim_dir * 7.0) as Vector3


func _step_arc(delta: float) -> void:
	if not _is_channeling or _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	_locked_target = _find_magnetized_enemy()
	var end_pos: Vector3
	var has_target: bool = (_locked_target != null)

	if has_target:
		end_pos = EnchantLightningLink.get_body_anchor_pos(_locked_target)
	else:
		# Sans cible aimantée, l'arc crépite dans le vide devant le lanceur sur ~6.5m
		var raw_dist: float = _aim_origin.distance_to(_remote_end_pos)
		var idle_reach: float = minf(6.5, maxf(2.0, raw_dist))
		end_pos = _aim_origin + _aim_dir * idle_reach

	_sfx_accum += delta
	if _sfx_accum >= 0.36:
		_sfx_accum = 0.0
		var pitch: float = 1.28 if has_target else 1.42
		SpellAudioManager.play_lightning_cast(self, end_pos, pitch, -5.2)

	if _is_auth and has_target:
		_tick_accum += delta
		if _tick_accum >= _effective_tick:
			_tick_accum = fmod(_tick_accum, _effective_tick)
			_apply_arc_tick(_locked_target, end_pos)

	_jitter_accum += delta
	if _jitter_accum >= JITTER_STEP:
		_jitter_accum = 0.0
		_rebuild_geometry(_hand_pos, end_pos, has_target)


func _find_magnetized_enemy() -> Node3D:
	var best_mob: Node3D = null
	var best_dot: float = cos(deg_to_rad(magnet_half_angle_deg))
	var max_r_sq: float = arc_range * arc_range

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_health <= 0.0:
			continue

		var anchor: Vector3 = EnchantLightningLink.get_body_anchor_pos(mob)
		var diff: Vector3 = anchor - _aim_origin
		var d_sq: float = diff.length_squared()
		if d_sq > max_r_sq or d_sq < 0.02:
			continue

		var dist: float = sqrt(d_sq)
		var dir_to: Vector3 = diff / dist
		var align: float = _aim_dir.dot(dir_to)
		# Très proche (< 2.5m), cône plus permissif pour le combat rapproché
		var eff_align: float = align + (0.08 if dist < 2.5 else 0.0)
		if eff_align >= best_dot:
			best_dot = eff_align
			best_mob = mob

	return best_mob


func _apply_arc_tick(mob: Node3D, _hit_pos: Vector3) -> void:
	if attack_component == null or mob == null or not is_instance_valid(mob):
		return

	var mid: int = mob.get_instance_id()
	var hb: HitboxComponent = _hitbox_cache.get(mid) as HitboxComponent
	if hb == null or not is_instance_valid(hb):
		# Les HitboxComponent sur les monstres squelettiques (ex: dumb, creep, scout, tree_man, ogre_boss)
		# sont attachées sous Skeleton3D/BoneAttachment3D. On filtre sur le type natif "Area3D" puis `is HitboxComponent`.
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

	if hb != null:
		attack_component.global_position = _hand_pos
		hb.receive_hit(attack_component)


func _rebuild_geometry(start_pt: Vector3, end_pt: Vector3, locked: bool) -> void:
	var dist: float = start_pt.distance_to(end_pt)
	if dist < 0.08:
		return

	var base_thick: float = 0.042 if locked else 0.024
	var spread: float = 0.22 if locked else 0.34
	var orb_s: float = base_thick * 2.2

	_start_orb.visible = true
	_start_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * orb_s), start_pt)
	_end_orb.visible = locked
	if locked:
		_end_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (orb_s * 1.35)), end_pt)

	var dir: Vector3 = (end_pt - start_pt) / dist
	var seg_len: float = dist / float(SEGMENTS)

	for s: int in range(STRAND_COUNT):
		var segs: Array = _strands[s]
		var pts: PackedVector3Array = PackedVector3Array()
		pts.resize(SEGMENTS + 1)
		pts[0] = start_pt
		pts[SEGMENTS] = end_pt

		var s_thick: float = base_thick * (1.0 if s == 0 else 1.55)
		for j: int in range(1, SEGMENTS):
			var mid: Vector3 = start_pt + dir * (seg_len * float(j))
			var arch: float = sin((float(j) / float(SEGMENTS)) * PI)
			var jitter: Vector3 = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.85, 0.85),
				randf_range(-1.0, 1.0)
			)
			if jitter.length_squared() > 0.001:
				jitter = jitter.normalized() * randf_range(0.2, 1.0) * spread * (0.3 + 0.7 * arch)
			pts[j] = mid + jitter

		for j: int in range(SEGMENTS):
			var p1: Vector3 = pts[j]
			var p2: Vector3 = pts[j + 1]
			var d_seg: Vector3 = p2 - p1
			var d_len: float = d_seg.length()
			var mi: MeshInstance3D = segs[j] as MeshInstance3D
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
