extends Node3D

static var _pentagon_mesh: CylinderMesh = null
static var _flake_mesh: PrismMesh = null
static var _outer_ice_mat: StandardMaterial3D = null
static var _core_ice_mat: StandardMaterial3D = null
static var _flake_mat: StandardMaterial3D = null
static var _wake_proc: ParticleProcessMaterial = null
static var _bounce_proc: ParticleProcessMaterial = null

@export var ram_duration: float = 3.4
@export var ram_speed: float = 19.5
@export var steer_turn_rate: float = 0.26
@export var post_bounce_lock: float = 0.65
@export var shield_max_hp_ratio: float = 0.20
@export var hit_cooldown_per_mob: float = 0.65
@export var bounce_cooldown: float = 0.12
@export var cancel_min_time: float = 0.45
@export var third_person_distance: float = 4.6

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster_body: CharacterBody3D = null
var _cam: Camera3D = null
var _health_comp: HealthComponent = null
var _stats_comp: StatsComponent = null
var _monolith_root: Node3D = null
var _main_block_mi: MeshInstance3D = null
var _inner_core_mi: MeshInstance3D = null
var _wake_particles: GPUParticles3D = null

var _is_auth: bool = true
var _is_local_player: bool = false
var _active: bool = false
var _state_restored: bool = false

var _elapsed: float = 0.0
var _linger_timer: float = 0.0
var _bounce_cd: float = 0.0
var _post_bounce_timer: float = 0.0
var _vy: float = -6.0
var _granted_shield: float = 0.0
var _impact_radius: float = 2.05

var _slide_dir: Vector3 = Vector3.FORWARD
var _prev_remote_pos: Vector3 = Vector3.ZERO
var _saved_cam_pos: Vector3 = Vector3(0.0, 0.74, -0.25)
var _has_saved_cam: bool = false
var _cam_blend: float = 0.0
var _smoothed_cam_dist: float = 4.0

var _saved_layer: int = 2
var _saved_mask: int = 257
var _exception_bodies: Array[PhysicsBody3D] = []
var _hit_cooldowns: Dictionary = {}


static func _ensure_shared_visuals() -> void:
	if _pentagon_mesh == null:
		_pentagon_mesh = CylinderMesh.new()
		_pentagon_mesh.top_radius = 1.15
		_pentagon_mesh.bottom_radius = 1.22
		_pentagon_mesh.height = 2.15
		_pentagon_mesh.radial_segments = 5
		_pentagon_mesh.rings = 0

	if _flake_mesh == null:
		_flake_mesh = PrismMesh.new()
		_flake_mesh.size = Vector3(0.16, 0.24, 0.08)

	if _outer_ice_mat == null:
		_outer_ice_mat = StandardMaterial3D.new()
		_outer_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outer_ice_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_outer_ice_mat.albedo_color = Color(0.44, 0.84, 1.0, 0.76)
		_outer_ice_mat.emission_enabled = true
		_outer_ice_mat.emission = Color(0.22, 0.68, 1.15, 1.0)
		_outer_ice_mat.emission_energy_multiplier = 1.25
		_outer_ice_mat.roughness = 0.12
		_outer_ice_mat.metallic = 0.12

	if _core_ice_mat == null:
		_core_ice_mat = StandardMaterial3D.new()
		_core_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_core_ice_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_core_ice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_ice_mat.albedo_color = Color(0.72, 1.85, 2.95, 0.72)

	if _flake_mat == null:
		_flake_mat = StandardMaterial3D.new()
		_flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flake_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flake_mat.vertex_color_use_as_albedo = true
		_flake_mat.albedo_color = Color(0.72, 1.75, 2.75, 0.9)

	if _wake_proc == null:
		var wp: ParticleProcessMaterial = ParticleProcessMaterial.new()
		wp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		wp.emission_box_extents = Vector3(0.75, 0.35, 0.45)
		wp.direction = Vector3(0.0, 0.35, 1.0)
		wp.spread = 34.0
		wp.initial_velocity_min = 2.8
		wp.initial_velocity_max = 6.5
		wp.gravity = Vector3(0.0, -3.5, 0.0)
		wp.damping_min = 3.0
		wp.damping_max = 6.0
		wp.scale_min = 0.55
		wp.scale_max = 1.25
		wp.color = Color(0.68, 1.65, 2.55, 0.88)
		_wake_proc = wp

	if _bounce_proc == null:
		var bp: ParticleProcessMaterial = ParticleProcessMaterial.new()
		bp.particle_flag_align_y = true
		bp.direction = Vector3(0.0, 0.45, 1.0)
		bp.spread = 58.0
		bp.initial_velocity_min = 6.5
		bp.initial_velocity_max = 13.5
		bp.gravity = Vector3(0.0, -14.0, 0.0)
		bp.scale_min = 0.65
		bp.scale_max = 1.45
		bp.color = Color(0.85, 2.0, 3.1, 0.95)
		_bounce_proc = bp


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_build_monolith_visuals()


func _build_monolith_visuals() -> void:
	_monolith_root = Node3D.new()
	_monolith_root.name = "GlacialMonolith"
	add_child(_monolith_root)

	_main_block_mi = MeshInstance3D.new()
	_main_block_mi.mesh = _pentagon_mesh
	_main_block_mi.material_override = _outer_ice_mat
	_main_block_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main_block_mi.position = Vector3(0.0, 0.08, 0.0)
	_main_block_mi.rotation = Vector3(0.0, PI, 0.0)
	_monolith_root.add_child(_main_block_mi)

	_inner_core_mi = MeshInstance3D.new()
	_inner_core_mi.mesh = _pentagon_mesh
	_inner_core_mi.material_override = _core_ice_mat
	_inner_core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inner_core_mi.scale = Vector3(0.78, 0.78, 0.78)
	_inner_core_mi.position = Vector3(0.0, 0.08, 0.0)
	_inner_core_mi.rotation = Vector3(0.0, PI, 0.0)
	_monolith_root.add_child(_inner_core_mi)

	_wake_particles = GPUParticles3D.new()
	_wake_particles.material_override = _flake_mat
	_wake_particles.process_material = _wake_proc
	_wake_particles.draw_pass_1 = _flake_mesh
	_wake_particles.amount = 30
	_wake_particles.lifetime = 0.55
	_wake_particles.fixed_fps = 30
	_wake_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake_particles.position = Vector3(0.0, -0.84, 0.92)
	_monolith_root.add_child(_wake_particles)
	_wake_particles.emitting = true


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	_caster_body = caster as CharacterBody3D
	if _caster_body == null:
		queue_free()
		return

	_is_auth = (not multiplayer.has_multiplayer_peer() or _caster_body.is_multiplayer_authority())
	_is_local_player = (_caster_body.is_in_group("Player") and _caster_body.is_multiplayer_authority())
	global_position = _caster_body.global_position
	_prev_remote_pos = _caster_body.global_position

	var feet_offset: float = 1.0
	var cshape: CollisionShape3D = _caster_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cshape != null and cshape.shape is CapsuleShape3D:
		var cap: CapsuleShape3D = cshape.shape as CapsuleShape3D
		feet_offset = maxf(0.0, cap.height * 0.5 - cshape.position.y)
	var block_center_y: float = -feet_offset + 1.05
	if _main_block_mi != null:
		_main_block_mi.position.y = block_center_y
	if _inner_core_mi != null:
		_inner_core_mi.position.y = block_center_y
	if _wake_particles != null:
		_wake_particles.position = Vector3(0.0, -feet_offset + 0.14, 0.92)

	if attack_component != null:
		attack_component.on_execute(_caster_body, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(_caster_body, target_data)
		_impact_radius = scaling_component.final_impact_radius
		var visual_scale: float = clampf(scaling_component.final_aoe_multiplier, 0.85, 1.65)
		if _monolith_root != null:
			_monolith_root.scale = Vector3.ONE * visual_scale

	var ab_data: AbilityData = target_data.get("ability_data") as AbilityData
	var lvl_mult: float = SpellScalingComponent.resolve_level_power_multiplier(_caster_body, ab_data, target_data)

	_cam = _caster_body.get_node_or_null("Camera3D") as Camera3D
	_health_comp = _caster_body.get_node_or_null("HealthComponent") as HealthComponent
	_stats_comp = _caster_body.find_child("StatsComponent", true, false) as StatsComponent

	var init_dir: Vector3 = -_caster_body.global_transform.basis.z
	if _cam != null:
		init_dir = -_cam.global_transform.basis.z
	init_dir.y = 0.0
	if init_dir.length_squared() > 0.001:
		_slide_dir = init_dir.normalized()
	else:
		_slide_dir = Vector3.FORWARD

	_orient_monolith(_slide_dir)

	if _is_auth:
		_caster_body.set("external_motion_override", true)
		_caster_body.set("is_in_transformation", true)
		if _caster_body.has_method("set_first_person_arms_visible"):
			_caster_body.call("set_first_person_arms_visible", false)

		if _cam != null and _is_local_player:
			_saved_cam_pos = _cam.position
			_has_saved_cam = true
			_cam_blend = 0.0
			_smoothed_cam_dist = 0.6

		_saved_layer = _caster_body.collision_layer
		_saved_mask = _caster_body.collision_mask
		_caster_body.collision_layer = 0
		_caster_body.collision_mask = (_saved_mask | 128) & ~256
		_add_enemy_exceptions()

		if _stats_comp != null:
			_stats_comp.set_or_update_modifier("knockback_resistance", StatModifier.Type.FLAT, 50.0, "glacial_ram")

		if _health_comp != null:
			var max_hp: float = _health_comp.get_max_health()
			_granted_shield = maxf(12.0, max_hp * shield_max_hp_ratio * lvl_mult)
			if _health_comp.current_shield < _granted_shield:
				_health_comp.set_shield(_granted_shield)

	_active = true
	SpellAudioManager.play_ice_cast(self, global_position, 0.86, 0.6)


func _add_enemy_exceptions() -> void:
	if _caster_body == null or not is_instance_valid(_caster_body) or get_tree() == null:
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
	if not _active:
		_linger_timer -= delta
		if _linger_timer <= 0.0:
			queue_free()
		return

	if _caster_body == null or not is_instance_valid(_caster_body) or _caster_body.get("is_dead") == true:
		_finish_ram()
		return

	_elapsed += delta
	if _bounce_cd > 0.0:
		_bounce_cd = maxf(0.0, _bounce_cd - delta)
	if _post_bounce_timer > 0.0:
		_post_bounce_timer = maxf(0.0, _post_bounce_timer - delta)

	if _is_auth:
		if _elapsed >= ram_duration:
			_finish_ram()
			return
		if _elapsed >= cancel_min_time and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_finish_ram()
			return

		_add_enemy_exceptions()
		_tick_hit_cooldowns(delta)

		if _post_bounce_timer <= 0.0:
			var aim_flat: Vector3 = -_caster_body.global_transform.basis.z
			if _cam != null:
				aim_flat = -_cam.global_transform.basis.z
			aim_flat.y = 0.0
			if aim_flat.length_squared() > 0.001:
				aim_flat = aim_flat.normalized()
				var ang_diff: float = _slide_dir.signed_angle_to(aim_flat, Vector3.UP)
				var step_ang: float = clampf(ang_diff, -steer_turn_rate * delta, steer_turn_rate * delta)
				_slide_dir = _slide_dir.rotated(Vector3.UP, step_ang).normalized()

		if _caster_body.is_on_floor():
			_vy = -6.0
		else:
			_vy += _caster_body.get_gravity().y * delta

		_caster_body.velocity = Vector3(_slide_dir.x * ram_speed, _vy, _slide_dir.z * ram_speed)
		_caster_body.move_and_slide()

		_check_wall_tree_bounce()
		_ram_nearby_enemies()

		global_position = _caster_body.global_position
		_orient_monolith(_slide_dir)
		_update_third_person_camera(delta)
	else:
		if _elapsed >= ram_duration:
			_finish_ram()
			return
		var cur_pos: Vector3 = _caster_body.global_position
		var move_delta: Vector3 = cur_pos - _prev_remote_pos
		move_delta.y = 0.0
		if move_delta.length_squared() > 0.0004:
			_slide_dir = move_delta.normalized()
		_prev_remote_pos = cur_pos
		global_position = cur_pos
		_orient_monolith(_slide_dir)


func _update_third_person_camera(delta: float) -> void:
	if _cam == null or not _has_saved_cam or not _is_local_player:
		return

	_cam_blend = move_toward(_cam_blend, 1.0, delta * 5.8)

	var pivot_world: Vector3 = _caster_body.global_position + Vector3(0.0, 1.55, 0.0)
	var cam_back: Vector3 = _cam.global_transform.basis.z
	if cam_back.length_squared() < 0.001:
		cam_back = _caster_body.global_transform.basis.z
	cam_back = cam_back.normalized()

	var desired_dist: float = third_person_distance
	var safe_dist: float = desired_dist
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var ray_end: Vector3 = pivot_world + cam_back * (desired_dist + 0.32)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pivot_world, ray_end, 1 | 128)
		var excl: Array[RID] = [_caster_body.get_rid()]
		query.exclude = excl
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			var hit_pos: Vector3 = hit["position"] as Vector3
			var hit_d: float = pivot_world.distance_to(hit_pos) - 0.30
			safe_dist = clampf(hit_d, 0.65, desired_dist)

	if safe_dist < _smoothed_cam_dist:
		_smoothed_cam_dist = safe_dist
	else:
		_smoothed_cam_dist = move_toward(_smoothed_cam_dist, safe_dist, delta * 14.0)

	var target_world: Vector3 = pivot_world + cam_back * _smoothed_cam_dist
	var target_local: Vector3 = _caster_body.to_local(target_world)
	_cam.position = _saved_cam_pos.lerp(target_local, _cam_blend)


func _check_wall_tree_bounce() -> void:
	if _bounce_cd > 0.0 or _caster_body == null:
		return
	var count: int = _caster_body.get_slide_collision_count()
	for i: int in range(count):
		var col: KinematicCollision3D = _caster_body.get_slide_collision(i)
		if col == null:
			continue
		var n: Vector3 = col.get_normal()
		if absf(n.y) < 0.48:
			var flat_n: Vector3 = Vector3(n.x, 0.0, n.z)
			if flat_n.length_squared() < 0.001:
				continue
			flat_n = flat_n.normalized()
			if _slide_dir.dot(flat_n) < -0.05:
				_slide_dir = _slide_dir.bounce(flat_n).normalized()
				_caster_body.velocity.x = _slide_dir.x * ram_speed
				_caster_body.velocity.z = _slide_dir.z * ram_speed
				_bounce_cd = bounce_cooldown
				_post_bounce_timer = post_bounce_lock
				var hit_pt: Vector3 = col.get_position()
				SpellAudioManager.play_ice_cast(self, hit_pt, 1.24, -0.6)
				_spawn_bounce_burst(hit_pt, flat_n)
				break


func _spawn_bounce_burst(world_pos: Vector3, normal_dir: Vector3) -> void:
	var burst: GPUParticles3D = GPUParticles3D.new()
	burst.material_override = _flake_mat
	burst.process_material = _bounce_proc
	burst.draw_pass_1 = _flake_mesh
	burst.amount = 18
	burst.lifetime = 0.38
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.fixed_fps = 30
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	burst.global_position = world_pos
	var look_target: Vector3 = world_pos + normal_dir
	if world_pos.distance_squared_to(look_target) > 0.001:
		burst.look_at(look_target, Vector3.UP)
	burst.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)


func _tick_hit_cooldowns(delta: float) -> void:
	if _hit_cooldowns.is_empty():
		return
	var expired_keys: Array[int] = []
	for key_var: Variant in _hit_cooldowns.keys():
		var eid: int = int(key_var)
		var rem: float = float(_hit_cooldowns[eid]) - delta
		if rem <= 0.0:
			expired_keys.append(eid)
		else:
			_hit_cooldowns[eid] = rem
	for eid_del: int in expired_keys:
		_hit_cooldowns.erase(eid_del)


func _ram_nearby_enemies() -> void:
	if attack_component == null or _caster_body == null or get_tree() == null:
		return

	var center: Vector3 = _caster_body.global_position
	var max_dist: float = _impact_radius + 0.35
	var max_dist_sq: float = max_dist * max_dist
	attack_component.global_position = center - _slide_dir * 0.65

	for node: Node in get_tree().get_nodes_in_group("Enemie"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob) or mob == _caster_body:
			continue
		if mob.get("is_dead") == true:
			continue
		var eid: int = mob.get_instance_id()
		if _hit_cooldowns.has(eid):
			continue

		var diff: Vector3 = mob.global_position - center
		if absf(diff.y) > 2.5:
			continue
		var flat_sq: float = diff.x * diff.x + diff.z * diff.z
		if flat_sq > max_dist_sq:
			continue

		var hb: HitboxComponent = _find_mob_hitbox(mob)
		if hb != null:
			_hit_cooldowns[eid] = hit_cooldown_per_mob
			hb.receive_hit(attack_component)
			SpellAudioManager.play_ice_cast(self, mob.global_position, 1.12, -2.0)


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


func _orient_monolith(dir: Vector3) -> void:
	if _monolith_root == null:
		return
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.001:
		return
	flat = flat.normalized()
	var cur_scale: Vector3 = _monolith_root.scale
	_monolith_root.basis = Basis.looking_at(flat, Vector3.UP).scaled(cur_scale)


func _finish_ram() -> void:
	if not _active:
		return
	_active = false
	_restore_state()

	if _caster_body != null and is_instance_valid(_caster_body):
		SpellAudioManager.play_ice_cast(self, _caster_body.global_position, 1.28, -1.5)
		_spawn_bounce_burst(_caster_body.global_position + Vector3(0.0, 0.4, 0.0), _slide_dir)

	if _wake_particles != null:
		_wake_particles.emitting = false
	if _monolith_root != null:
		_monolith_root.visible = false

	_linger_timer = 0.45


func _restore_state() -> void:
	if _state_restored:
		return
	_state_restored = true

	if _is_auth:
		if _cam != null and is_instance_valid(_cam) and _has_saved_cam:
			_cam.position = _saved_cam_pos

		if _caster_body != null and is_instance_valid(_caster_body):
			for pb: PhysicsBody3D in _exception_bodies:
				if pb != null and is_instance_valid(pb):
					_caster_body.remove_collision_exception_with(pb)
			_exception_bodies.clear()

			_caster_body.collision_layer = _saved_layer
			_caster_body.collision_mask = _saved_mask
			if _caster_body.has_method("set_first_person_arms_visible"):
				_caster_body.call("set_first_person_arms_visible", true)
			_caster_body.velocity = Vector3(_slide_dir.x * 5.5, minf(0.0, _caster_body.velocity.y), _slide_dir.z * 5.5)
			_caster_body.set("external_motion_override", false)
			_caster_body.set("is_in_transformation", false)

		if _stats_comp != null and is_instance_valid(_stats_comp):
			_stats_comp.remove_modifier_by_source("glacial_ram")

		if _health_comp != null and is_instance_valid(_health_comp) and _granted_shield > 0.0:
			if _health_comp.current_shield > 0.0:
				_health_comp.set_shield(maxf(0.0, _health_comp.current_shield - _granted_shield))
			_granted_shield = 0.0


func _exit_tree() -> void:
	_restore_state()
