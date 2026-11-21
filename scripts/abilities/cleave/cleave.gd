class_name CleaveAbility
extends Node3D

const BASE_BOX_SIZE: Vector3 = Vector3(3.8, 1.35, 3.0)
const BASE_BOX_OFFSET: Vector3 = Vector3(0.0, 0.15, -1.60)
const MAX_LIFETIME_FAILSAFE: float = 5.0

@onready var weapon_trail: CleaveWeaponTrail = $WeaponTrail
@onready var sweep_pivot: Node3D = $SweepPivot
@onready var attack_component: AttackComponent = $SweepPivot/AttackComponent
@onready var collision_shape: CollisionShape3D = $SweepPivot/AttackComponent/CollisionShape3D
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var caster: Node3D = null
var _cached_target_data: Dictionary = {}
var _is_swing_active: bool = false
var _has_started_swing: bool = false
var _has_ended_swing: bool = false
var _is_cleaning_up: bool = false
var _alive_time: float = 0.0
var _skill_bar_ref: Node = null

func _ready() -> void:
	if collision_shape != null:
		collision_shape.disabled = true
	if scaling_component != null and attack_component != null and scaling_component.attack_component == null:
		scaling_component.attack_component = attack_component

func start_complex_cast(player: Node3D) -> void:
	caster = player
	if collision_shape != null:
		collision_shape.disabled = true

	if caster != null and is_instance_valid(caster):
		_align_sweep_pivot()
		var skill_bar: Node = caster.get_node_or_null("SkillBarComponent")
		if skill_bar == null:
			skill_bar = caster.find_child("SkillBarComponent", true, false)
		if skill_bar != null:
			_skill_bar_ref = skill_bar
			var cast_ability: AbilityData = skill_bar.get("casting_ability") as AbilityData
			if cast_ability != null:
				_cached_target_data["ability_data"] = cast_ability
			if skill_bar.has_signal("cast_canceled"):
				var cancel_cb := Callable(self, "_on_caster_cast_canceled")
				if not skill_bar.is_connected("cast_canceled", cancel_cb):
					skill_bar.connect("cast_canceled", cancel_cb)

func on_mid_cast_event(event_name: String) -> void:
	match event_name:
		"cleave_start":
			_begin_cleave_swing()
		"cleave_end":
			_end_cleave_swing()

func execute(player: Node3D, target_data: Dictionary) -> void:
	if player != null and is_instance_valid(player):
		caster = player
	for key: Variant in target_data.keys():
		_cached_target_data[key] = target_data[key]

	_disconnect_cancel_signal()
	_is_cleaning_up = true

	if not _has_started_swing:
		_begin_cleave_swing()
		await get_tree().create_timer(0.20).timeout
		if not is_inside_tree():
			return
		_end_cleave_swing()
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			queue_free()
	else:
		if _is_swing_active and not _has_ended_swing:
			_end_cleave_swing()
		await get_tree().create_timer(0.45).timeout
		if is_inside_tree():
			queue_free()

func _process(delta: float) -> void:
	_alive_time += delta
	if _is_swing_active:
		_align_sweep_pivot()

	if not _is_cleaning_up and _alive_time >= MAX_LIFETIME_FAILSAFE:
		_is_cleaning_up = true
		_disconnect_cancel_signal()
		_end_cleave_swing()
		queue_free()

func _begin_cleave_swing() -> void:
	if _has_started_swing:
		return
	_has_started_swing = true
	_is_swing_active = true

	_align_sweep_pivot()

	var is_auth: bool = _is_caster_authoritative()

	if caster != null and is_instance_valid(caster):
		if scaling_component != null:
			scaling_component.on_execute(caster, _cached_target_data)
		if attack_component != null:
			attack_component.reset_hit_entities()
			attack_component.on_execute(caster, _cached_target_data)
			attack_component.is_active_for_network = is_auth

	var aoe_mult: float = 1.0
	if scaling_component != null and scaling_component.final_aoe_multiplier > 0.0:
		aoe_mult = scaling_component.final_aoe_multiplier

	if collision_shape != null:
		var duplicated_box: BoxShape3D = null
		if collision_shape.shape is BoxShape3D:
			duplicated_box = (collision_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		else:
			duplicated_box = BoxShape3D.new()

		duplicated_box.size = Vector3(
			BASE_BOX_SIZE.x * aoe_mult,
			BASE_BOX_SIZE.y,
			BASE_BOX_SIZE.z * aoe_mult
		)
		collision_shape.shape = duplicated_box
		collision_shape.position = Vector3(
			BASE_BOX_OFFSET.x,
			BASE_BOX_OFFSET.y,
			BASE_BOX_OFFSET.z * aoe_mult
		)
		collision_shape.disabled = not is_auth

	if weapon_trail != null and caster != null and is_instance_valid(caster):
		weapon_trail.start_trail(caster)

func _is_caster_authoritative() -> bool:
	if caster == null or not is_instance_valid(caster):
		return true
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return true
	return caster.is_multiplayer_authority()

func _end_cleave_swing() -> void:
	_is_swing_active = false
	_has_ended_swing = true
	if collision_shape != null:
		collision_shape.disabled = true
	if weapon_trail != null:
		weapon_trail.stop_trail()

func _align_sweep_pivot() -> void:
	if caster == null or not is_instance_valid(caster) or sweep_pivot == null:
		return

	global_position = caster.global_position
	sweep_pivot.global_position = caster.global_position

	var aim_node: Node3D = caster.get_node_or_null("Camera3D") as Node3D
	if aim_node == null:
		aim_node = caster

	var forward: Vector3 = -aim_node.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -caster.global_transform.basis.z
		forward.y = 0.0

	if forward.length_squared() > 0.0001:
		var yaw: float = atan2(-forward.x, -forward.z)
		sweep_pivot.global_rotation = Vector3(0.0, yaw, 0.0)

func _on_caster_cast_canceled() -> void:
	if _is_cleaning_up:
		return
	_is_cleaning_up = true
	_disconnect_cancel_signal()
	_end_cleave_swing()
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree():
		queue_free()

func _disconnect_cancel_signal() -> void:
	if _skill_bar_ref != null and is_instance_valid(_skill_bar_ref):
		var cancel_cb := Callable(self, "_on_caster_cast_canceled")
		if _skill_bar_ref.has_signal("cast_canceled") and _skill_bar_ref.is_connected("cast_canceled", cancel_cb):
			_skill_bar_ref.disconnect("cast_canceled", cancel_cb)
	_skill_bar_ref = null
