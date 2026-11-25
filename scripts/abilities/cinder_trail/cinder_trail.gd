extends Node3D

@export var buff_duration: float = 4.0
@export var patch_duration: float = 2.8
@export var patch_spacing: float = 0.95
@export var tick_interval: float = 0.35

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _caster: Node3D = null
var _elapsed: float = 0.0
var _dist_accum: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _scaled_fire_dmg: float = 8.0
var _scaled_radius: float = 1.15
var _is_auth: bool = true


func _ready() -> void:
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false


func execute(caster: Node3D, target_data: Dictionary) -> void:
	_caster = caster
	if _caster == null or not is_instance_valid(_caster):
		queue_free()
		return

	_is_auth = (not multiplayer.has_multiplayer_peer() or _caster.is_multiplayer_authority())
	global_position = _caster.global_position
	_last_pos = _caster.global_position

	if attack_component != null:
		attack_component.on_execute(_caster, target_data)
	if scaling_component != null:
		scaling_component.on_execute(_caster, target_data)
		_scaled_radius = scaling_component.final_impact_radius
	if attack_component != null:
		_scaled_fire_dmg = maxf(1.0, attack_component.damage_fire)

	SpellAudioManager.play_fire_cast(self, global_position, 1.08, -2.2)
	_spawn_cinder_patch(_caster.global_position)


func _process(delta: float) -> void:
	if _caster == null or not is_instance_valid(_caster) or _caster.get("is_dead") == true:
		queue_free()
		return

	_elapsed += delta
	if _elapsed >= buff_duration:
		queue_free()
		return

	global_position = _caster.global_position
	var cur_flat: Vector3 = Vector3(_caster.global_position.x, 0.0, _caster.global_position.z)
	var prev_flat: Vector3 = Vector3(_last_pos.x, 0.0, _last_pos.z)
	var step_d: float = cur_flat.distance_to(prev_flat)
	_last_pos = _caster.global_position
	_dist_accum += step_d

	if _dist_accum >= patch_spacing:
		_dist_accum = fmod(_dist_accum, patch_spacing)
		_spawn_cinder_patch(_caster.global_position)


func _spawn_cinder_patch(origin_pos: Vector3) -> void:
	var spawn_pos: Vector3 = origin_pos
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin_pos + Vector3(0.0, 1.2, 0.0),
			origin_pos - Vector3(0.0, 3.5, 0.0),
			1
		)
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			spawn_pos = hit["position"] as Vector3

	var patch: CinderPatch = CinderPatch.new()
	get_tree().root.add_child(patch)
	patch.global_position = spawn_pos
	patch.setup_cinder(_caster, _scaled_radius, patch_duration, _scaled_fire_dmg, tick_interval, _is_auth)
