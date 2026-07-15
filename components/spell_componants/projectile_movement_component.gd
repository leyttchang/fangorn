class_name ProjectileMovementComponent
extends Node

@export var projectile_speed: float = 30.0

func on_execute(caster: Node3D, _target_data: Dictionary) -> void:
	# On récupère le RigidBody3D parent pour le pousser
	var body: RigidBody3D = get_parent()
	var cast_point = caster.find_child("CastPoint", true, false)
	
	if cast_point != null:
		body.global_transform = cast_point.global_transform
		var forward_direction = -cast_point.global_transform.basis.z.normalized()
		body.apply_central_impulse(forward_direction * projectile_speed)
	else:
		body.global_position = caster.global_position + Vector3(0, 1.5, 0) 
		var forward_direction = -caster.global_transform.basis.z.normalized()
		body.apply_central_impulse(forward_direction * projectile_speed)
