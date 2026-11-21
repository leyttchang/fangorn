class_name LeapSlamAbility
extends Node3D

@export_group("Distance Curve (Physical / Melee Scaling)")
@export_range(4.0, 20.0, 0.1) var base_leap_distance: float = 8.5
@export_range(0.0, 3.0, 0.05) var phys_distance_scaling: float = 0.90
@export_range(8.0, 50.0, 0.5) var max_leap_distance: float = 28.0

@export_group("Height Curve (Physical / Melee Scaling)")
@export_range(1.6, 10.0, 0.1) var base_leap_height: float = 3.2
@export_range(0.0, 3.0, 0.05) var phys_height_scaling: float = 1.05
@export_range(3.0, 25.0, 0.5) var max_leap_height: float = 11.0

@export_group("Air Speed Curve (Attack Speed Scaling)")
@export_range(4.0, 30.0, 0.1) var base_leap_speed: float = 12.8
@export_range(3.0, 20.0, 0.1) var min_leap_speed: float = 7.5
@export_range(10.0, 60.0, 0.5) var max_leap_speed: float = 28.0

@export_group("Air Control & Safety")
@export_range(0.0, 1.0, 0.01) var air_steer_strength: float = 0.14
@export_range(0.5, 10.0, 0.1) var max_air_timeout: float = 3.5

var slam_impact: Node3D = null
var decal: Decal = null
var rock_chunk: GPUParticles3D = null
var wave_impact: MeshInstance3D = null
var attack_component: AttackComponent = null
var collision_shape: CollisionShape3D = null
var scaling_component: SpellScalingComponent = null

var _caster: Node3D = null
var _caster_body: CharacterBody3D = null
var _cached_target_data: Dictionary = {}

var _is_authoritative: bool = true
var _is_local_player: bool = false
var _is_jumping: bool = false
var _has_slammed: bool = false
var _motion_override_active: bool = false
var _remote_peak_reached: bool = false

var _leap_dir: Vector3 = Vector3.FORWARD
var _horiz_vel: Vector3 = Vector3.ZERO
var _leap_speed: float = 12.8
var _vy: float = 0.0
var _jump_gravity: float = 9.8
var _duration: float = 0.65
var _atk_spd: float = 1.0
var _elapsed: float = 0.0
var _start_y: float = 0.0
var _prev_caster_y: float = 0.0
var _remote_descended: bool = false


func _ready() -> void:
	_resolve_nodes()
	set_physics_process(_is_jumping)


func _exit_tree() -> void:
	_release_caster_motion_override()


func _resolve_nodes() -> void:
	if slam_impact == null:
		slam_impact = get_node_or_null("SlamImpact") as Node3D
	if decal == null:
		decal = get_node_or_null("SlamImpact/Decal") as Decal
	if rock_chunk == null:
		rock_chunk = get_node_or_null("SlamImpact/rock_chunk") as GPUParticles3D
	if wave_impact == null:
		wave_impact = get_node_or_null("SlamImpact/wave_impact") as MeshInstance3D
	if attack_component == null:
		attack_component = get_node_or_null("SlamImpact/AttackComponent") as AttackComponent
	if collision_shape == null:
		collision_shape = get_node_or_null("SlamImpact/AttackComponent/CollisionShape3D") as CollisionShape3D
	if scaling_component == null:
		scaling_component = get_node_or_null("SpellScalingComponent") as SpellScalingComponent
	if scaling_component != null and attack_component != null and scaling_component.attack_component == null:
		scaling_component.attack_component = attack_component


func compute_leap_parameters(caster: Node3D) -> Dictionary:
	var atk_spd: float = 1.0
	var stats: Node = caster.find_child("StatsComponent", true, false) if caster != null else null
	var equipment: Node = caster.find_child("EquipmentComponent", true, false) if caster != null else null
	var skill_bar: Node = caster.find_child("SkillBarComponent", true, false) if caster != null else null

	if skill_bar != null and skill_bar.has_method("get_effective_attack_speed_factor"):
		if skill_bar.get("player_stats") == null and stats != null:
			skill_bar.set("player_stats", stats)
		atk_spd = float(skill_bar.call("get_effective_attack_speed_factor", true, 0.45))
	else:
		var factor: float = 1.0
		if stats != null and stats.has_method("get_stat_value"):
			var p_speed: float = float(stats.call("get_stat_value", "attack_speed"))
			if p_speed > 0.0:
				factor *= p_speed
		if equipment != null and equipment.get("equipped_items") is Dictionary:
			var eq_dict: Dictionary = equipment.get("equipped_items") as Dictionary
			if eq_dict.has("main_hand"):
				var weapon_ref: Variant = eq_dict["main_hand"]
				if weapon_ref is Object and (weapon_ref as Object).get("base_attack_speed") != null:
					var w_aps: float = float((weapon_ref as Object).get("base_attack_speed"))
					if w_aps > 0.0:
						factor *= lerpf(1.0, w_aps / 1.2, 0.45)
		atk_spd = maxf(factor, 0.15)

	var phys_stat: float = 1.0
	if stats != null and stats.has_method("get_stat_value"):
		var raw_phys: float = float(stats.call("get_stat_value", "physical_damage"))
		if raw_phys > 0.0:
			phys_stat = raw_phys

	var weapon_heavy_bonus: float = 0.0
	if equipment != null and equipment.get("equipped_items") is Dictionary:
		var eq_items: Dictionary = equipment.get("equipped_items") as Dictionary
		if eq_items.has("main_hand"):
			var main_weapon: Variant = eq_items["main_hand"]
			if main_weapon is Object and (main_weapon as Object).get("base_damage") != null:
				var weapon_base_dmg: float = float((main_weapon as Object).get("base_damage"))
				weapon_heavy_bonus = maxf(0.0, (weapon_base_dmg - 20.0) / 120.0)

	var melee_bonus: float = maxf(0.0, phys_stat - 1.0) + weapon_heavy_bonus

	var d_val: float = clampf(base_leap_distance * (1.0 + melee_bonus * phys_distance_scaling), 4.0, max_leap_distance)
	var h_val: float = clampf(base_leap_height * (1.0 + melee_bonus * phys_height_scaling), 1.6, max_leap_height)
	var v_val: float = clampf(base_leap_speed * atk_spd, min_leap_speed, max_leap_speed)
	var t_val: float = maxf(0.20, d_val / v_val)

	return {
		"distance": d_val,
		"height": h_val,
		"speed": v_val,
		"duration": t_val,
		"atk_spd": atk_spd,
		"melee_bonus": melee_bonus
	}


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_resolve_nodes()
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	_caster = caster
	_caster_body = caster as CharacterBody3D
	_cached_target_data = target_data.duplicate()

	if slam_impact != null:
		slam_impact.visible = false
	if collision_shape != null:
		collision_shape.disabled = true

	var params: Dictionary = compute_leap_parameters(caster)
	var h_val: float = float(params["height"])
	_leap_speed = float(params["speed"])
	_duration = float(params["duration"])
	_atk_spd = float(params["atk_spd"])

	_start_y = caster.global_position.y
	_prev_caster_y = _start_y
	_elapsed = 0.0
	_remote_peak_reached = false
	_remote_descended = false
	global_position = caster.global_position

	_is_authoritative = _check_caster_authority(caster)

	if not _is_authoritative:
		if attack_component != null:
			attack_component.is_active_for_network = false
		_is_jumping = true
		set_physics_process(true)
		return

	if attack_component != null:
		attack_component.is_active_for_network = true

	_is_local_player = (
		caster.is_in_group("Player")
		or caster.is_in_group("player")
		or caster.get_node_or_null("Camera3D") != null
		or caster.find_child("SkillBarComponent", true, false) != null
	)

	_leap_dir = _compute_initial_leap_direction(caster, _is_local_player)
	_jump_gravity = (8.0 * h_val) / (_duration * _duration)
	_vy = (4.0 * h_val) / _duration
	_horiz_vel = _leap_dir * _leap_speed

	caster.set("external_motion_override", true)
	_motion_override_active = true

	_play_caster_animation(caster, "leap_slam_air", 0.6 / maxf(_duration, 0.05))

	_is_jumping = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _is_jumping:
		set_physics_process(false)
		return

	if _caster == null or not is_instance_valid(_caster):
		_is_jumping = false
		set_physics_process(false)
		queue_free()
		return

	_elapsed += delta
	global_position = _caster.global_position

	if not _is_authoritative:
		var cur_y: float = _caster.global_position.y
		var dy_speed: float = (cur_y - _prev_caster_y) / maxf(delta, 0.001)
		_prev_caster_y = cur_y

		if cur_y > _start_y + 0.25:
			_remote_peak_reached = true
		if _remote_peak_reached and dy_speed < -0.6:
			_remote_descended = true

		var remote_min_air: float = minf(0.14, _duration * 0.35)
		var remote_settled_after_descent: bool = _remote_descended and absf(dy_speed) < 0.75 and _elapsed >= _duration * 0.45
		var remote_returned_y: bool = _remote_peak_reached and cur_y <= _start_y + 0.08 and absf(dy_speed) < 1.5 and _elapsed >= _duration * 0.65
		var remote_timeout: bool = _elapsed >= maxf(_duration * 1.30, _duration + 0.18)
		if _elapsed >= remote_min_air and (remote_settled_after_descent or remote_returned_y or remote_timeout):
			_is_jumping = false
			set_physics_process(false)
			if attack_component != null:
				attack_component.is_active_for_network = false
			_trigger_ground_slam(_caster.global_position)
		return

	# Léger contrôle aérien horizontal si le joueur local maintient une direction
	if _is_local_player and air_steer_strength > 0.0 and _has_movement_actions():
		var in_v: Vector2 = Input.get_vector("left", "right", "forward", "backward")
		if in_v.length() > 0.1:
			var steer_world: Vector3 = _caster.global_transform.basis * Vector3(in_v.x, 0.0, in_v.y)
			steer_world.y = 0.0
			if steer_world.length_squared() > 0.0001:
				steer_world = steer_world.normalized()
				_leap_dir = _leap_dir.lerp(steer_world, clampf(air_steer_strength * delta * 6.0, 0.0, 1.0)).normalized()
				_horiz_vel = _leap_dir * _leap_speed

	_vy = maxf(-45.0, _vy - _jump_gravity * delta)

	if _caster_body != null:
		_caster_body.velocity = Vector3(_horiz_vel.x, _vy, _horiz_vel.z)
		_caster_body.move_and_slide()
		if _caster_body.is_on_ceiling() and _vy > 0.0:
			_vy = 0.0
	else:
		_caster.global_position += Vector3(_horiz_vel.x, _vy, _horiz_vel.z) * delta

	var min_air_check: float = minf(0.10, _duration * 0.25)
	if _elapsed >= min_air_check:
		var hit_floor: bool = _vy <= 0.0 and _caster_body != null and _caster_body.is_on_floor()
		var timed_out: bool = _elapsed >= max_air_timeout
		var virtual_floor_hit: bool = _elapsed >= _duration and _caster.global_position.y <= _start_y + 0.05

		if hit_floor or timed_out or virtual_floor_hit:
			_finish_authoritative_landing()


func _finish_authoritative_landing() -> void:
	_is_jumping = false
	set_physics_process(false)
	_release_caster_motion_override()

	if _caster_body != null and is_instance_valid(_caster_body):
		_caster_body.velocity = Vector3(
			_horiz_vel.x * 0.18,
			minf(0.0, _caster_body.velocity.y),
			_horiz_vel.z * 0.18
		)

	if _caster != null and is_instance_valid(_caster):
		_play_caster_animation(_caster, "leap_slam_land", clampf(_atk_spd, 0.85, 2.2))
		_trigger_ground_slam(_caster.global_position)
	else:
		queue_free()


func _trigger_ground_slam(impact_pos: Vector3) -> void:
	if _has_slammed:
		return
	_has_slammed = true
	_resolve_nodes()

	global_position = impact_pos
	if slam_impact != null:
		slam_impact.global_position = impact_pos
		slam_impact.visible = true

	if _caster != null and is_instance_valid(_caster):
		if scaling_component != null:
			scaling_component.on_execute(_caster, _cached_target_data)
		if attack_component != null:
			attack_component.on_execute(_caster, _cached_target_data)

	if attack_component != null:
		attack_component.is_active_for_network = _is_authoritative
		attack_component.reset_hit_entities()

	var final_r: float = 4.2
	var aoe_mult: float = 1.0
	if scaling_component != null:
		if scaling_component.final_impact_radius > 0.0:
			final_r = scaling_component.final_impact_radius
		else:
			final_r = scaling_component.base_impact_radius
		if scaling_component.final_aoe_multiplier > 0.0:
			aoe_mult = scaling_component.final_aoe_multiplier

	if collision_shape != null and collision_shape.shape is CylinderShape3D:
		var cyl: CylinderShape3D = (collision_shape.shape as CylinderShape3D).duplicate() as CylinderShape3D
		cyl.radius = final_r
		collision_shape.shape = cyl

	if decal != null:
		decal.size = Vector3(final_r * 2.0, 1.8, final_r * 2.0)
		decal.modulate = Color(0.65, 0.46, 0.26, 1.0)
		var decal_tween: Tween = create_tween()
		decal_tween.tween_property(decal, "modulate", Color(0.34, 0.2244, 0.1088, 1.0), 0.28)
		decal_tween.tween_interval(1.9)
		decal_tween.tween_property(decal, "modulate:a", 0.0, 1.25)

	if rock_chunk != null:
		rock_chunk.scale = Vector3.ONE * aoe_mult
		rock_chunk.restart()
		rock_chunk.emitting = true

	if wave_impact != null:
		wave_impact.visible = true
		wave_impact.scale = Vector3(0.3, 0.35, 0.3)
		var wave_mat: StandardMaterial3D = null
		if wave_impact.material_override is StandardMaterial3D:
			wave_mat = (wave_impact.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			wave_impact.material_override = wave_mat
		if wave_mat != null:
			var col: Color = wave_mat.albedo_color
			col.a = 0.68
			wave_mat.albedo_color = col
		var wave_tween: Tween = create_tween()
		wave_tween.set_parallel(true)
		wave_tween.tween_property(
			wave_impact,
			"scale",
			Vector3(final_r * 0.55, 0.12, final_r * 0.55),
			0.32
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if wave_mat != null:
			wave_tween.tween_property(wave_mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		wave_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(wave_impact):
				wave_impact.visible = false
		)

	if collision_shape != null and _is_authoritative:
		collision_shape.disabled = false
		var hit_tween: Tween = create_tween()
		hit_tween.tween_interval(0.15)
		hit_tween.tween_callback(func() -> void:
			if is_instance_valid(collision_shape):
				collision_shape.disabled = true
		)

	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(3.6)
	cleanup_tween.tween_callback(queue_free)


func _release_caster_motion_override() -> void:
	if _motion_override_active and _caster != null and is_instance_valid(_caster):
		_caster.set("external_motion_override", false)
	_motion_override_active = false


func _check_caster_authority(in_caster: Node3D) -> bool:
	if in_caster == null:
		return true
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return true
	return in_caster.is_multiplayer_authority()


func _has_movement_actions() -> bool:
	return (
		InputMap.has_action("left")
		and InputMap.has_action("right")
		and InputMap.has_action("forward")
		and InputMap.has_action("backward")
	)


func _compute_initial_leap_direction(in_caster: Node3D, use_local_input: bool) -> Vector3:
	if use_local_input and _has_movement_actions():
		var in_v: Vector2 = Input.get_vector("left", "right", "forward", "backward")
		if in_v.length() > 0.1:
			var input_dir: Vector3 = in_caster.global_transform.basis * Vector3(in_v.x, 0.0, in_v.y)
			input_dir.y = 0.0
			if input_dir.length_squared() > 0.0001:
				return input_dir.normalized()

	var forward_horiz: Vector3 = Vector3(
		-in_caster.global_transform.basis.z.x,
		0.0,
		-in_caster.global_transform.basis.z.z
	)
	if forward_horiz.length_squared() > 0.0001:
		return forward_horiz.normalized()
	return Vector3.FORWARD


func _play_caster_animation(in_caster: Node3D, anim_name: String, speed: float) -> void:
	var anim_player: AnimationPlayer = in_caster.get_node_or_null("Camera3D/attack_animation") as AnimationPlayer
	var skill_bar: Node = in_caster.find_child("SkillBarComponent", true, false)
	if anim_player == null and skill_bar != null and skill_bar.get("anim_player") is AnimationPlayer:
		anim_player = skill_bar.get("anim_player") as AnimationPlayer

	var anim_tree: AnimationTree = null
	if skill_bar != null and skill_bar.get("anim_tree") is AnimationTree:
		anim_tree = skill_bar.get("anim_tree") as AnimationTree
	if anim_tree == null:
		anim_tree = in_caster.find_child("AnimationTree", true, false) as AnimationTree

	if anim_player != null and anim_player.has_animation(anim_name):
		if anim_tree != null:
			anim_tree.active = false
		anim_player.play(anim_name)
		anim_player.speed_scale = speed
