class_name KnockbackComponent
extends Node

@export var stats_component: StatsComponent
@export var minimum_force_threshold: float = 0.0

var target_body: Node3D

func _ready() -> void:
	target_body = get_parent()

func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:
	# On accepte la direction envoyée par l'attaque (qui gère l'angle)
	if push_direction.length_squared() > 0.001:
		push_direction = push_direction.normalized()
	
	var resistance: float = 0.0
	if stats_component != null:
		var stat_val = stats_component.get_stat_value("knockback_resistance")
		if stat_val != null:
			resistance = stat_val
			
	var final_force = raw_knockback_force - resistance
	final_force = max(0.0, final_force)
	
	if final_force >= minimum_force_threshold:
		if target_body.is_multiplayer_authority():
			_apply_physics(push_direction, final_force)
		else:
			rpc_id(target_body.get_multiplayer_authority(), "_rpc_apply_physics", push_direction, final_force)

func _apply_physics(push_direction: Vector3, final_force: float) -> void:
	if target_body is CharacterBody3D:
		target_body.velocity += push_direction * final_force
	elif target_body is RigidBody3D:
		target_body.apply_central_impulse(push_direction * final_force)

@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_physics(push_direction: Vector3, final_force: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != target_body.get_multiplayer_authority():
		# Vrifie que le sender est soit le serveur, soit qqun qui a le droit de nous frapper
		pass 
	_apply_physics(push_direction, final_force)
