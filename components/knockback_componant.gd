class_name KnockbackComponent
extends Node

@export var stats_component: StatsComponent
@export var minimum_force_threshold: float = 0.0

var target_body: Node3D

func _ready() -> void:
	target_body = get_parent()

func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:
	# On s'assure que le recul reste bien plat sur le sol
	push_direction.y = 0 
	push_direction = push_direction.normalized()
	
	var resistance: float = 0.0
	if stats_component != null:
		var stat_val = stats_component.get_stat_value("knockback_resistance")
		if stat_val != null:
			resistance = stat_val
			
	var final_force = raw_knockback_force - resistance
	final_force = max(0.0, final_force)
	
	if final_force >= minimum_force_threshold:
		if target_body is CharacterBody3D:
			target_body.velocity += push_direction * final_force
		elif target_body is RigidBody3D:
			target_body.apply_central_impulse(push_direction * final_force)
