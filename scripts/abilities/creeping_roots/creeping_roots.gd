extends Node3D

const POOL_SIZE: int = 16

static var _arch_mesh: TorusMesh = null
static var _thorn_mesh: CylinderMesh = null
static var _sigil_mesh: CylinderMesh = null
static var _bark_mat: StandardMaterial3D = null
static var _rune_mat: StandardMaterial3D = null
static var _sigil_mat: StandardMaterial3D = null
static var _query_sphere_cache: Dictionary = {}

@export var steer_speed: float = 12.5
@export var erupt_spacing: float = 0.62
@export var base_tick_interval: float = 0.35

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

class RootCluster:
	var root_node: Node3D
	var active: bool = false
	var age: float = 0.0
	var max_age: float = 0.95
	var target_scale: float = 1.0

var _clusters: Array[RootCluster] = []
var _pool_cursor: int = 0
var _head_visual: MeshInstance3D = null

var _caster: Node3D = null
var _head_pos: Vector3 = Vector3.ZERO
var _target_ground_pos: Vector3 = Vector3.ZERO
var _is_channeling: bool = false
var _is_auth: bool = true
var _dist_since_erupt: float = 0.0
var _time_since_erupt: float = 0.0
var _effective_tick_interval: float = 0.22
var _effective_steer_speed: float = 12.5
var _erupt_radius: float = 1.65
var _audio_cooldown: float = 0.0
var _enemy_next_hit_msec: Dictionary = {}


static func _ensure_shared_meshes() -> void:
	if _arch_mesh == null:
		_arch_mesh = TorusMesh.new()
		_arch_mesh.inner_radius = 0.28
		_arch_mesh.outer_radius = 0.44
		_arch_mesh.rings = 10
		_arch_mesh.ring_segments = 6

	if _thorn_mesh == null:
		_thorn_mesh = CylinderMesh.new()
		_thorn_mesh.top_radius = 0.02
		_thorn_mesh.bottom_radius = 0.11
		_thorn_mesh.height = 0.78
		_thorn_mesh.radial_segments = 6
		_thorn_mesh.rings = 1

	if _sigil_mesh == null:
		_sigil_mesh = CylinderMesh.new()
		_sigil_mesh.top_radius = 0.52
		_sigil_mesh.bottom_radius = 0.52
		_sigil_mesh.height = 0.03
		_sigil_mesh.radial_segments = 14

	if _bark_mat == null:
		_bark_mat = StandardMaterial3D.new()
		_bark_mat.albedo_color = Color(0.16, 0.10, 0.18, 1.0)
		_bark_mat.roughness = 0.88
		_bark_mat.emission_enabled = true
		_bark_mat.emission = Color(0.55, 0.16, 0.95, 1.0)
		_bark_mat.emission_energy_multiplier = 0.85

	if _rune_mat == null:
		_rune_mat = StandardMaterial3D.new()
		_rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rune_mat.albedo_color = Color(2.15, 0.75, 3.25, 1.0)

	if _sigil_mat == null:
		_sigil_mat = StandardMaterial3D.new()
		_sigil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sigil_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_sigil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sigil_mat.albedo_color = Color(1.55, 0.52, 2.65, 0.55)


static func _get_query_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(8, int(roundf(rad * 20.0)))
	if _query_sphere_cache.has(key):
		return _query_sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 20.0
	_query_sphere_cache[key] = sph
	return sph


func _ready() -> void:
	_ensure_shared_meshes()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_head_visual = MeshInstance3D.new()
	_head_visual.mesh = _sigil_mesh
	_head_visual.material_override = _sigil_mat
	_head_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head_visual.visible = false
	add_child(_head_visual)

	for i: int in range(POOL_SIZE):
		var holder: Node3D = Node3D.new()
		holder.name = "RootCluster_" + str(i)
		holder.visible = false

		var arch: MeshInstance3D = MeshInstance3D.new()
		arch.mesh = _arch_mesh
		arch.material_override = _bark_mat
		arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arch.rotation.x = PI * 0.5
		arch.position.y = 0.08
		holder.add_child(arch)

		var thorn_a: MeshInstance3D = MeshInstance3D.new()
		thorn_a.mesh = _thorn_mesh
		thorn_a.material_override = _bark_mat
		thorn_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		thorn_a.position = Vector3(0.16, 0.30, 0.05)
		thorn_a.rotation = Vector3(0.32, 0.4, -0.28)
		holder.add_child(thorn_a)

		var rune_spike: MeshInstance3D = MeshInstance3D.new()
		rune_spike.mesh = _thorn_mesh
		rune_spike.material_override = _rune_mat
		rune_spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rune_spike.scale = Vector3(0.45, 0.72, 0.45)
		rune_spike.position = Vector3(-0.14, 0.28, -0.06)
		rune_spike.rotation = Vector3(-0.26, -0.5, 0.30)
		holder.add_child(rune_spike)

		add_child(holder)
		var rc: RootCluster = RootCluster.new()
		rc.root_node = holder
		_clusters.append(rc)


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
		_erupt_radius = scaling_component.final_impact_radius

	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick_interval = maxf(0.08, base_tick_interval / cast_spd)
	_effective_steer_speed = steer_speed * sqrt(cast_spd)

	var fwd: Vector3 = -_caster.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	_head_pos = _snap_to_ground(_caster.global_position + fwd * 1.4, _caster.global_position.y)
	_target_ground_pos = _resolve_ground_target(aim_data)
	_is_channeling = true
	_head_visual.visible = true
	_head_visual.global_position = _head_pos + Vector3(0.0, 0.06, 0.0)

	_erupt_at(_head_pos, fwd)


func update_channel(caster: Node3D, delta: float, aim_data: Dictionary) -> void:
	_caster = caster
	var cast_spd: float = maxf(0.25, float(aim_data.get("casting_speed", 1.0)))
	_effective_tick_interval = maxf(0.08, base_tick_interval / cast_spd)
	_effective_steer_speed = steer_speed * sqrt(cast_spd)
	_target_ground_pos = _resolve_ground_target(aim_data)
	_step_head(delta)


func update_remote_aim(aim_point: Vector3, aim_dir: Vector3) -> void:
	var fake_data: Dictionary = {
		"aim_point": aim_point,
		"aim_dir": aim_dir,
		"has_hit": true
	}
	_target_ground_pos = _resolve_ground_target(fake_data)


func stop_channel() -> void:
	_is_channeling = false
	if _head_visual != null:
		_head_visual.visible = false


func _process(delta: float) -> void:
	if _audio_cooldown > 0.0:
		_audio_cooldown -= delta

	# Pour les clients distants (qui reçoivent update_remote_aim mais pas update_channel), on avance la tête ici
	if _is_channeling and not _is_auth:
		_step_head(delta)

	var any_active: bool = false
	for rc: RootCluster in _clusters:
		if not rc.active:
			continue
		any_active = true
		rc.age += delta
		var u: float = rc.age / rc.max_age
		if u >= 1.0:
			rc.active = false
			rc.root_node.visible = false
			continue

		var env: float = 1.0
		if u < 0.18:
			env = sin((u / 0.18) * PI * 0.5)
		elif u > 0.65:
			env = cos(((u - 0.65) / 0.35) * PI * 0.5)
		var s: float = maxf(0.02, rc.target_scale * env)
		rc.root_node.scale = Vector3(rc.target_scale, s, rc.target_scale)

	if not _is_channeling and not any_active:
		queue_free()


func _step_head(delta: float) -> void:
	if not _is_channeling or _caster == null or not is_instance_valid(_caster):
		return

	var to_target: Vector3 = _target_ground_pos - _head_pos
	var flat_to: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var flat_len: float = flat_to.length()
	var move_dir: Vector3 = Vector3.FORWARD
	var moved_dist: float = 0.0

	if flat_len > 0.08:
		move_dir = flat_to / flat_len
		var step: float = minf(flat_len, _effective_steer_speed * delta)
		var next_flat: Vector3 = _head_pos + move_dir * step
		# Garde la racine dans la portée max autour du lanceur
		var max_r: float = 24.0
		var from_caster: Vector3 = Vector3(next_flat.x - _caster.global_position.x, 0.0, next_flat.z - _caster.global_position.z)
		if from_caster.length() > max_r:
			from_caster = from_caster.normalized() * max_r
			next_flat.x = _caster.global_position.x + from_caster.x
			next_flat.z = _caster.global_position.z + from_caster.z
		var snapped: Vector3 = _snap_to_ground(next_flat, _head_pos.y)
		moved_dist = Vector2(snapped.x - _head_pos.x, snapped.z - _head_pos.z).length()
		_head_pos = snapped

	if _head_visual != null:
		_head_visual.global_position = _head_pos + Vector3(0.0, 0.06, 0.0)
		_head_visual.rotate_y(delta * 4.5)

	_dist_since_erupt += moved_dist
	_time_since_erupt += delta

	if _dist_since_erupt >= erupt_spacing or _time_since_erupt >= _effective_tick_interval:
		_dist_since_erupt = 0.0
		_time_since_erupt = 0.0
		_erupt_at(_head_pos, move_dir)


func _erupt_at(pos: Vector3, dir: Vector3) -> void:
	var rc: RootCluster = _clusters[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _clusters.size()

	rc.active = true
	rc.age = 0.0
	rc.max_age = 0.90
	var aoe_mult: float = scaling_component.final_aoe_multiplier if scaling_component != null else 1.0
	rc.target_scale = randf_range(0.88, 1.18) * aoe_mult

	var yaw: float = atan2(dir.x, dir.z) + randf_range(-0.45, 0.45)
	rc.root_node.visible = true
	rc.root_node.global_position = pos
	rc.root_node.rotation = Vector3(0.0, yaw, 0.0)
	rc.root_node.scale = Vector3(rc.target_scale, 0.05, rc.target_scale)

	if _audio_cooldown <= 0.0:
		_audio_cooldown = 0.28
		SpellAudioManager.play_ice_windup(self, pos, 0.72, -5.5)

	if _is_auth and attack_component != null:
		_damage_enemies_at(pos)


func _damage_enemies_at(pos: Vector3) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _get_query_sphere(_erupt_radius)
	params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.75, 0.0))
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var hits: Array[Dictionary] = space_state.intersect_shape(params, 16)
	if hits.is_empty():
		return

	attack_component.global_position = pos
	var now_ms: int = Time.get_ticks_msec()
	var cooldown_ms: int = maxi(120, int(roundf(_effective_tick_interval * 1000.0)))
	var hit_entities_this_pulse: Dictionary = {}
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
		var t: float = clampf((ground_y - origin.y) / dir.y, 1.0, 24.0)
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
			return res["position"] as Vector3
	return Vector3(pos.x, fallback_y, pos.z)
