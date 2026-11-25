extends Node3D


class SlabEntry extends RefCounted:
	var body: StaticBody3D = null
	var visual_root: Node3D = null
	var rid: RID = RID()
	var top_pos: Vector3 = Vector3.ZERO
	var up_normal: Vector3 = Vector3.UP
	var age: float = 0.0


class IcicleDrop extends RefCounted:
	var mesh_inst: MeshInstance3D = null
	var pos: Vector3 = Vector3.ZERO
	var vel: Vector3 = Vector3(0.0, -26.0, 0.0)
	var floor_y: float = 0.0
	var age: float = 0.0


static var _slab_shape: BoxShape3D = null
static var _slab_box_mesh: BoxMesh = null
static var _slab_rim_mesh: BoxMesh = null
static var _hanging_cone_mesh: CylinderMesh = null
static var _falling_icicle_mesh: CylinderMesh = null
static var _shard_mesh: PrismMesh = null
static var _slab_mat: StandardMaterial3D = null
static var _rim_mat: StandardMaterial3D = null
static var _icicle_mat: StandardMaterial3D = null
static var _shard_mat: StandardMaterial3D = null
static var _shatter_proc: ParticleProcessMaterial = null
static var _sphere_cache: Dictionary = {}

@export var form_duration: float = 4.5
@export var slab_lifetime: float = 3.8
@export var slab_spacing: float = 0.60
@export var sprint_speed_bonus: float = 0.38
@export var icicle_interval: float = 0.28
@export var icicle_fall_speed: float = 26.0
@export var min_pitch_deg: float = -32.0
@export var max_pitch_deg: float = 34.0
@export var jump_climb_pitch_deg: float = 32.0

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _caster_body: CharacterBody3D = null
var _cam: Camera3D = null
var _stats_comp: StatsComponent = null

var _is_auth: bool = true
var _forming: bool = false
var _speed_buff_active: bool = false
var _was_jump_held: bool = false
var _jump_lift_accum: float = 0.0
var _elapsed: float = 0.0
var _icicle_timer: float = 0.0
var _feet_offset: float = 1.0
var _impact_radius: float = 2.0

var _chain_xz: Vector2 = Vector2.ZERO
var _chain_top_y: float = 0.0
var _last_fwd_flat: Vector3 = Vector3.FORWARD
var _prev_caster_pos: Vector3 = Vector3.ZERO
var _smoothed_pitch: float = 0.0

var _slabs: Array[SlabEntry] = []
var _slab_rids: Array[RID] = []
var _icicles: Array[IcicleDrop] = []
var _active_burst_count: int = 0
var _last_targeted_mob_id: int = 0


static func _ensure_shared_visuals() -> void:
	if _slab_shape == null:
		_slab_shape = BoxShape3D.new()
		_slab_shape.size = Vector3(2.2, 0.24, 1.35)

	if _slab_box_mesh == null:
		_slab_box_mesh = BoxMesh.new()
		_slab_box_mesh.size = Vector3(2.2, 0.24, 1.35)

	if _slab_rim_mesh == null:
		_slab_rim_mesh = BoxMesh.new()
		_slab_rim_mesh.size = Vector3(0.12, 0.10, 1.35)

	if _hanging_cone_mesh == null:
		_hanging_cone_mesh = CylinderMesh.new()
		_hanging_cone_mesh.top_radius = 0.085
		_hanging_cone_mesh.bottom_radius = 0.006
		_hanging_cone_mesh.height = 0.52
		_hanging_cone_mesh.radial_segments = 5
		_hanging_cone_mesh.rings = 0

	if _falling_icicle_mesh == null:
		_falling_icicle_mesh = CylinderMesh.new()
		_falling_icicle_mesh.top_radius = 0.13
		_falling_icicle_mesh.bottom_radius = 0.008
		_falling_icicle_mesh.height = 0.92
		_falling_icicle_mesh.radial_segments = 6
		_falling_icicle_mesh.rings = 0

	if _shard_mesh == null:
		_shard_mesh = PrismMesh.new()
		_shard_mesh.size = Vector3(0.14, 0.24, 0.07)

	if _slab_mat == null:
		_slab_mat = StandardMaterial3D.new()
		_slab_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_slab_mat.albedo_color = Color(0.45, 0.86, 1.0, 0.72)
		_slab_mat.emission_enabled = true
		_slab_mat.emission = Color(0.20, 0.65, 1.15, 1.0)
		_slab_mat.emission_energy_multiplier = 1.15
		_slab_mat.roughness = 0.12

	if _rim_mat == null:
		_rim_mat = StandardMaterial3D.new()
		_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_rim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rim_mat.albedo_color = Color(0.75, 1.95, 3.0, 0.75)

	if _icicle_mat == null:
		_icicle_mat = StandardMaterial3D.new()
		_icicle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_icicle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_icicle_mat.albedo_color = Color(0.72, 1.85, 2.85, 0.92)

	if _shard_mat == null:
		_shard_mat = StandardMaterial3D.new()
		_shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shard_mat.vertex_color_use_as_albedo = true
		_shard_mat.albedo_color = Color(0.82, 2.0, 3.1, 0.92)

	if _shatter_proc == null:
		var sp: ParticleProcessMaterial = ParticleProcessMaterial.new()
		sp.particle_flag_align_y = true
		sp.direction = Vector3(0.0, 1.0, 0.0)
		sp.spread = 72.0
		sp.initial_velocity_min = 4.5
		sp.initial_velocity_max = 9.5
		sp.gravity = Vector3(0.0, -16.0, 0.0)
		sp.scale_min = 0.65
		sp.scale_max = 1.25
		sp.color = Color(0.80, 1.95, 3.0, 0.95)
		_shatter_proc = sp


static func _get_cached_sphere(rad: float) -> SphereShape3D:
	var key: int = maxi(10, int(roundf(rad * 10.0)))
	if _sphere_cache.has(key):
		return _sphere_cache[key] as SphereShape3D
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(key) / 10.0
	_sphere_cache[key] = sph
	return sph


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	# Keep root node at world origin so child StaticBody3D slabs stay fixed in world space
	global_transform = Transform3D.IDENTITY

	_caster_body = _caster as CharacterBody3D
	_cam = _caster.get_node_or_null("Camera3D") as Camera3D
	_stats_comp = _caster.find_child("StatsComponent", true, false) as StatsComponent
	_is_auth = (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())

	if _caster_body != null:
		var col_shape: CollisionShape3D = _caster_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_shape != null and col_shape.shape is CapsuleShape3D:
			var cap: CapsuleShape3D = col_shape.shape as CapsuleShape3D
			_feet_offset = maxf(0.4, cap.height * 0.5 - col_shape.position.y)

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)
		_impact_radius = scaling_component.final_impact_radius

	if _is_auth and _stats_comp != null:
		_stats_comp.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, sprint_speed_bonus, "ice_path")
		_speed_buff_active = true

	var start_pos: Vector3 = _caster.global_position
	_prev_caster_pos = start_pos
	_last_fwd_flat = _get_aim_flat_forward()
	var init_jump: bool = (_is_auth and Input.is_action_pressed("jump"))
	_was_jump_held = init_jump
	_smoothed_pitch = deg_to_rad(jump_climb_pitch_deg) if init_jump else _get_clamped_camera_pitch()

	var feet_y: float = start_pos.y - _feet_offset
	var ground_y: float = _sample_real_ground_y(Vector3(start_pos.x, feet_y + 1.4, start_pos.z))
	_chain_xz = Vector2(start_pos.x, start_pos.z)
	_chain_top_y = maxf(feet_y - 0.02, ground_y + 0.04)

	_forge_slab_at(_chain_xz, _chain_top_y, _last_fwd_flat, _smoothed_pitch)
	_advance_chain_and_forge(_last_fwd_flat, slab_spacing, _smoothed_pitch)
	if _is_auth:
		_assist_caster_step_up(init_jump)

	_forming = true
	SpellAudioManager.play_ice_cast(self, start_pos, 1.06, -0.8)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _forming:
		if _caster == null or not is_instance_valid(_caster) or _caster.get("is_dead") == true or _elapsed >= form_duration:
			_stop_forming()
		else:
			var jump_held: bool = (_is_auth and Input.is_action_pressed("jump"))
			_update_path_forging(delta, jump_held)
			if _is_auth:
				_assist_caster_step_up(jump_held)
			_was_jump_held = jump_held

	_tick_slabs(delta)
	_tick_icicle_spawner(delta)
	_tick_falling_icicles(delta)

	if not _forming and _slabs.is_empty() and _icicles.is_empty() and _active_burst_count <= 0:
		queue_free()


func _update_path_forging(delta: float, jump_held: bool) -> void:
	var cur_pos: Vector3 = _caster.global_position
	var caster_xz: Vector2 = Vector2(cur_pos.x, cur_pos.z)
	var feet_y: float = cur_pos.y - _feet_offset

	var move_vec: Vector3 = cur_pos - _prev_caster_pos
	_prev_caster_pos = cur_pos
	var move_flat: Vector3 = Vector3(move_vec.x, 0.0, move_vec.z)
	var horiz_speed: float = move_flat.length() / maxf(0.001, delta)
	var aim_flat: Vector3 = _get_aim_flat_forward()

	var travel_dir: Vector3 = aim_flat
	if move_flat.length_squared() > 0.0004:
		var move_norm: Vector3 = move_flat.normalized()
		travel_dir = (move_norm * 0.72 + aim_flat * 0.28).normalized()
	_last_fwd_flat = travel_dir

	var desired_pitch: float = _get_clamped_camera_pitch()
	if jump_held:
		# Holding Jump forces a steep upward ramp climb regardless of camera pitch
		desired_pitch = deg_to_rad(jump_climb_pitch_deg)
		_smoothed_pitch = maxf(_smoothed_pitch, deg_to_rad(22.0))
		_smoothed_pitch = move_toward(_smoothed_pitch, desired_pitch, delta * 14.0)
		if _caster_body != null and _caster_body.velocity.y > 1.2:
			_caster_body.velocity.y = 1.2
	else:
		var align_dot: float = travel_dir.dot(aim_flat)
		if align_dot < -0.25:
			desired_pitch = -desired_pitch
		_smoothed_pitch = move_toward(_smoothed_pitch, desired_pitch, delta * 5.2)

	# Immediately start tilting the ramp up beneath the player's feet the instant Jump is pressed
	if jump_held and not _was_jump_held:
		var ground_j: float = _sample_real_ground_y(Vector3(cur_pos.x, feet_y + 1.4, cur_pos.z))
		_chain_xz = caster_xz
		_chain_top_y = maxf(maxf(_chain_top_y, feet_y - 0.02), ground_j + 0.04)
		_forge_slab_at(_chain_xz, _chain_top_y, travel_dir, _smoothed_pitch)
		_advance_chain_and_forge(travel_dir, slab_spacing, _smoothed_pitch)

	# Re-anchor under the caster if they stepped off the path or jumped far away
	var high_thresh: float = 1.35 if jump_held else 0.55
	if feet_y > _chain_top_y + high_thresh or feet_y < _chain_top_y - 1.35 or caster_xz.distance_to(_chain_xz) > 2.8:
		var ground_re: float = _sample_real_ground_y(Vector3(cur_pos.x, feet_y + 1.4, cur_pos.z))
		_chain_xz = caster_xz
		_chain_top_y = maxf(feet_y - 0.02, ground_re + 0.04)
		_forge_slab_at(_chain_xz, _chain_top_y, travel_dir, _smoothed_pitch)

	# If holding Jump with very low horizontal movement, still elevate the ramp under the player smoothly
	if jump_held and horiz_speed < 2.2:
		_jump_lift_accum += delta * 4.4
		if _jump_lift_accum >= 0.28:
			var rise_step: float = minf(_jump_lift_accum, 0.38)
			_jump_lift_accum = 0.0
			_chain_xz = caster_xz
			_chain_top_y = maxf(_chain_top_y, feet_y) + rise_step
			_forge_slab_at(_chain_xz, _chain_top_y, travel_dir, deg_to_rad(14.0))
	else:
		_jump_lift_accum = 0.0

	var lead_xz: Vector2 = caster_xz + Vector2(travel_dir.x, travel_dir.z) * 0.58
	var dist_to_lead: float = _chain_xz.distance_to(lead_xz)
	var safety_steps: int = 0

	while dist_to_lead >= slab_spacing and safety_steps < 5:
		safety_steps += 1
		var step_2d: Vector2 = _chain_xz.direction_to(lead_xz)
		var step_dir: Vector3 = Vector3(step_2d.x, 0.0, step_2d.y)
		_advance_chain_and_forge(step_dir, slab_spacing, _smoothed_pitch)
		dist_to_lead = _chain_xz.distance_to(lead_xz)


func _advance_chain_and_forge(horiz_dir: Vector3, dist: float, pitch_rad: float) -> void:
	var dir_2d: Vector2 = Vector2(horiz_dir.x, horiz_dir.z)
	if dir_2d.length_squared() < 0.0001:
		dir_2d = Vector2(0.0, -1.0)
	else:
		dir_2d = dir_2d.normalized()

	_chain_xz += dir_2d * dist
	_chain_top_y += dist * tan(pitch_rad)

	var probe_y: float = _chain_top_y + 2.2
	var real_ground_y: float = _sample_real_ground_y(Vector3(_chain_xz.x, probe_y, _chain_xz.y))
	var eff_pitch: float = pitch_rad
	if _chain_top_y < real_ground_y + 0.05:
		_chain_top_y = real_ground_y + 0.05
		if eff_pitch < 0.0:
			eff_pitch = 0.0

	_forge_slab_at(_chain_xz, _chain_top_y, Vector3(dir_2d.x, 0.0, dir_2d.y), eff_pitch)


func _forge_slab_at(xz: Vector2, top_y: float, horiz_dir: Vector3, pitch_rad: float) -> void:
	var flat_dir: Vector3 = Vector3(horiz_dir.x, 0.0, horiz_dir.z)
	if flat_dir.length_squared() < 0.001:
		flat_dir = Vector3.FORWARD
	else:
		flat_dir = flat_dir.normalized()

	var yaw_basis: Basis = Basis.looking_at(flat_dir, Vector3.UP)
	var tilted_basis: Basis = yaw_basis * Basis(Vector3.RIGHT, pitch_rad)
	var up_vec: Vector3 = tilted_basis.y.normalized()

	var top_world: Vector3 = Vector3(xz.x, top_y, xz.y)
	var body_center: Vector3 = top_world - up_vec * 0.12

	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.transform = Transform3D(tilted_basis, body_center)
	add_child(sb)

	var cshape: CollisionShape3D = CollisionShape3D.new()
	cshape.shape = _slab_shape
	sb.add_child(cshape)

	var vis_root: Node3D = Node3D.new()
	sb.add_child(vis_root)

	var slab_mi: MeshInstance3D = MeshInstance3D.new()
	slab_mi.mesh = _slab_box_mesh
	slab_mi.material_override = _slab_mat
	slab_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vis_root.add_child(slab_mi)

	for side_s: int in [-1, 1]:
		var rim_mi: MeshInstance3D = MeshInstance3D.new()
		rim_mi.mesh = _slab_rim_mesh
		rim_mi.material_override = _rim_mat
		rim_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rim_mi.position = Vector3(float(side_s) * 1.04, 0.10, 0.0)
		vis_root.add_child(rim_mi)

	for ic_idx: int in range(3):
		var x_off: float = float(ic_idx - 1) * 0.68
		var z_off: float = -0.22 if (ic_idx % 2 == 0) else 0.24
		var hang_mi: MeshInstance3D = MeshInstance3D.new()
		hang_mi.mesh = _hanging_cone_mesh
		hang_mi.material_override = _icicle_mat
		hang_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hang_mi.position = Vector3(x_off, -0.36, z_off)
		vis_root.add_child(hang_mi)

	var entry: SlabEntry = SlabEntry.new()
	entry.body = sb
	entry.visual_root = vis_root
	entry.rid = sb.get_rid()
	entry.top_pos = top_world
	entry.up_normal = up_vec
	entry.age = 0.0
	_slabs.append(entry)
	_slab_rids.append(entry.rid)


func _assist_caster_step_up(jump_held: bool = false) -> void:
	if _caster_body == null or not is_instance_valid(_caster_body) or _slabs.is_empty():
		return

	var cpos: Vector3 = _caster_body.global_position
	var feet_y: float = cpos.y - _feet_offset
	var best_surface_y: float = -99999.0
	var found_slab: bool = false

	var start_idx: int = maxi(0, _slabs.size() - 8)
	for i: int in range(start_idx, _slabs.size()):
		var sl: SlabEntry = _slabs[i]
		if sl.body == null or not is_instance_valid(sl.body):
			continue
		var local_pt: Vector3 = sl.body.to_local(cpos)
		if absf(local_pt.x) <= 1.15 and absf(local_pt.z) <= 0.74:
			var n: Vector3 = sl.up_normal
			var denom: float = maxf(0.25, n.y)
			var surf_y: float = sl.top_pos.y - (n.x * (cpos.x - sl.top_pos.x) + n.z * (cpos.z - sl.top_pos.z)) / denom
			if surf_y > best_surface_y:
				best_surface_y = surf_y
				found_slab = true

	if not found_slab:
		return

	var step_tol: float = 0.58 if jump_held else 0.38
	if feet_y < best_surface_y and (best_surface_y - feet_y) <= step_tol:
		_caster_body.global_position.y = best_surface_y + _feet_offset + 0.012
		if _caster_body.velocity.y < 0.0 or jump_held:
			_caster_body.velocity.y = 0.0
	elif jump_held and feet_y >= best_surface_y and (feet_y - best_surface_y) <= 0.62:
		# Smoothly glue the caster to the ascending ramp instead of bunny-hopping from native jump velocity
		_caster_body.global_position.y = best_surface_y + _feet_offset + 0.012
		_caster_body.velocity.y = 0.0


func _tick_slabs(delta: float) -> void:
	if _slabs.is_empty():
		return

	var idx: int = _slabs.size() - 1
	while idx >= 0:
		var sl: SlabEntry = _slabs[idx]
		sl.age += delta
		if sl.age >= slab_lifetime:
			_slab_rids.erase(sl.rid)
			if sl.body != null and is_instance_valid(sl.body):
				sl.body.queue_free()
			_slabs.remove_at(idx)
		elif sl.age > slab_lifetime - 0.40 and sl.visual_root != null and is_instance_valid(sl.visual_root):
			var fade_ratio: float = clampf((slab_lifetime - sl.age) / 0.40, 0.05, 1.0)
			sl.visual_root.scale = Vector3(fade_ratio, fade_ratio, fade_ratio)
		idx -= 1


func _tick_icicle_spawner(delta: float) -> void:
	if _slabs.is_empty():
		return

	_icicle_timer += delta
	if _icicle_timer < icicle_interval:
		return
	_icicle_timer = fmod(_icicle_timer, icicle_interval)
	_spawn_icicle_under_bridge()


func _spawn_icicle_under_bridge() -> void:
	if _slabs.is_empty():
		return

	var chosen_slab: SlabEntry = null
	var chosen_mob: Node3D = null
	var best_score: float = 999999.0

	if get_tree() != null:
		for node: Node in get_tree().get_nodes_in_group("Enemie"):
			var mob: Node3D = node as Node3D
			if mob == null or not is_instance_valid(mob) or mob == _caster:
				continue
			if mob.get("is_dead") == true:
				continue
			var mpos: Vector3 = mob.global_position
			var mob_id: int = mob.get_instance_id()

			for sl: SlabEntry in _slabs:
				if mpos.y > sl.top_pos.y + 0.65:
					continue
				var dx: float = mpos.x - sl.top_pos.x
				var dz: float = mpos.z - sl.top_pos.z
				var h_dist_sq: float = dx * dx + dz * dz
				if h_dist_sq <= 12.25: # 3.5m horizontal radius
					var score: float = h_dist_sq + (4.5 if mob_id == _last_targeted_mob_id else 0.0)
					if score < best_score:
						best_score = score
						chosen_slab = sl
						chosen_mob = mob

	var spawn_pos: Vector3 = Vector3.ZERO
	var vel_vec: Vector3 = Vector3(0.0, -icicle_fall_speed, 0.0)

	if chosen_slab != null and chosen_mob != null:
		_last_targeted_mob_id = chosen_mob.get_instance_id()
		var to_mob_xz: Vector3 = chosen_mob.global_position - chosen_slab.top_pos
		to_mob_xz.y = 0.0
		var lateral_offset: Vector3 = to_mob_xz.limit_length(0.95)
		spawn_pos = chosen_slab.top_pos + lateral_offset + Vector3(0.0, -0.34, 0.0)

		var target_pt: Vector3 = chosen_mob.global_position + Vector3(0.0, 0.55, 0.0)
		var fall_vec: Vector3 = target_pt - spawn_pos
		if fall_vec.y > -0.6:
			fall_vec.y = -1.2
		vel_vec = fall_vec.normalized() * icicle_fall_speed
	else:
		chosen_slab = _slabs[_slabs.size() - 1]
		spawn_pos = chosen_slab.top_pos + Vector3(randf_range(-0.65, 0.65), -0.34, randf_range(-0.30, 0.30))

	var ground_below: float = _sample_real_ground_y(spawn_pos + Vector3(0.0, 0.8, 0.0))
	if spawn_pos.y < ground_below + 0.75:
		spawn_pos.y = ground_below + 0.85

	var ic_mi: MeshInstance3D = MeshInstance3D.new()
	ic_mi.mesh = _falling_icicle_mesh
	ic_mi.material_override = _icicle_mat
	ic_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ic_mi)

	var down_dir: Vector3 = vel_vec.normalized()
	var y_axis: Vector3 = -down_dir
	var ref_ax: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x_axis: Vector3 = ref_ax.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	ic_mi.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), spawn_pos)

	var drop: IcicleDrop = IcicleDrop.new()
	drop.mesh_inst = ic_mi
	drop.pos = spawn_pos
	drop.vel = vel_vec
	drop.floor_y = ground_below + 0.08
	drop.age = 0.0
	_icicles.append(drop)


func _tick_falling_icicles(delta: float) -> void:
	if _icicles.is_empty():
		return

	var idx: int = _icicles.size() - 1
	while idx >= 0:
		var drop: IcicleDrop = _icicles[idx]
		drop.age += delta
		drop.pos += drop.vel * delta
		if drop.mesh_inst != null and is_instance_valid(drop.mesh_inst):
			drop.mesh_inst.global_position = drop.pos

		var hit_ground: bool = (drop.pos.y <= drop.floor_y or drop.age >= 2.2)
		var hit_enemy: bool = _is_icicle_touching_enemy(drop.pos)

		if hit_ground or hit_enemy:
			var impact_pt: Vector3 = drop.pos
			if hit_ground and not hit_enemy:
				impact_pt.y = drop.floor_y
			_on_icicle_shatter(impact_pt)
			if drop.mesh_inst != null and is_instance_valid(drop.mesh_inst):
				drop.mesh_inst.queue_free()
			_icicles.remove_at(idx)
		idx -= 1


func _is_icicle_touching_enemy(pt: Vector3) -> bool:
	if get_tree() == null:
		return false
	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob == _caster:
			continue
		if mob.get("is_dead") == true:
			continue
		var mpos: Vector3 = mob.global_position
		if pt.y >= mpos.y - 0.5 and pt.y <= mpos.y + 1.85:
			var dx: float = pt.x - mpos.x
			var dz: float = pt.z - mpos.z
			if (dx * dx + dz * dz) <= 0.85:
				return true
	return false


func _on_icicle_shatter(impact_pos: Vector3) -> void:
	SpellAudioManager.play_ice_cast(self, impact_pos, 1.38, -4.8)

	_active_burst_count += 1
	var burst: GPUParticles3D = GPUParticles3D.new()
	burst.material_override = _shard_mat
	burst.process_material = _shatter_proc
	burst.draw_pass_1 = _shard_mesh
	burst.amount = 10
	burst.lifetime = 0.28
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.fixed_fps = 30
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	burst.global_position = impact_pos
	burst.emitting = true

	get_tree().create_timer(0.36).timeout.connect(func() -> void:
		_active_burst_count = maxi(0, _active_burst_count - 1)
		if is_instance_valid(burst):
			burst.queue_free()
	)

	if _is_auth and attack_component != null:
		_apply_icicle_aoe_damage(impact_pos, _impact_radius)


func _apply_icicle_aoe_damage(center: Vector3, radius: float) -> void:
	attack_component.global_position = center
	var seen: Dictionary = {}

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = _get_cached_sphere(radius)
		params.transform = Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.4, 0.0))
		params.collision_mask = 8
		params.collide_with_areas = true
		params.collide_with_bodies = false

		var hits: Array[Dictionary] = space_state.intersect_shape(params, 16)
		for entry: Dictionary in hits:
			var hb: HitboxComponent = entry.get("collider") as HitboxComponent
			if hb == null:
				continue
			var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
			if entity == null or entity == _caster or entity.is_in_group("Player"):
				continue
			var eid: int = entity.get_instance_id()
			if seen.has(eid):
				continue
			seen[eid] = true
			hb.receive_hit(attack_component)

	if get_tree() != null:
		var max_r: float = radius + 0.35
		var max_r_sq: float = max_r * max_r
		for node: Node in get_tree().get_nodes_in_group("Enemie"):
			var mob: Node3D = node as Node3D
			if mob == null or not is_instance_valid(mob) or mob == _caster:
				continue
			var eid_m: int = mob.get_instance_id()
			if seen.has(eid_m):
				continue
			var diff: Vector3 = mob.global_position - center
			if absf(diff.y) > 2.6:
				continue
			if (diff.x * diff.x + diff.z * diff.z) > max_r_sq:
				continue
			var mob_hb: HitboxComponent = _find_mob_hitbox(mob)
			if mob_hb != null:
				seen[eid_m] = true
				mob_hb.receive_hit(attack_component)


func _find_mob_hitbox(mob: Node3D) -> HitboxComponent:
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


func _sample_real_ground_y(origin: Vector3) -> float:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return origin.y - 2.0
	var ray_from: Vector3 = origin + Vector3(0.0, 2.5, 0.0)
	var ray_to: Vector3 = origin - Vector3(0.0, 65.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = _slab_rids
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		var hit_pt: Vector3 = hit["position"] as Vector3
		return hit_pt.y
	return origin.y - 65.0


func _get_aim_flat_forward() -> Vector3:
	var raw_fwd: Vector3 = Vector3.FORWARD
	if _cam != null and is_instance_valid(_cam):
		raw_fwd = -_cam.global_transform.basis.z
	elif _caster != null and is_instance_valid(_caster):
		raw_fwd = -_caster.global_transform.basis.z
	raw_fwd.y = 0.0
	if raw_fwd.length_squared() < 0.001:
		return Vector3.FORWARD
	return raw_fwd.normalized()


func _get_clamped_camera_pitch() -> float:
	var raw_pitch: float = 0.0
	if _cam != null and is_instance_valid(_cam):
		raw_pitch = _cam.rotation.x
	return clampf(raw_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func _stop_forming() -> void:
	if not _forming and not _speed_buff_active:
		return
	_forming = false
	_remove_speed_modifier()


func _remove_speed_modifier() -> void:
	if not _speed_buff_active:
		return
	_speed_buff_active = false
	if _is_auth and _stats_comp != null and is_instance_valid(_stats_comp):
		_stats_comp.remove_modifier_by_source("ice_path")


func _exit_tree() -> void:
	_remove_speed_modifier()
