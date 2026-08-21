# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_apply = '''	if final_force >= minimum_force_threshold:
		if target_body is CharacterBody3D:
			target_body.velocity += push_direction * final_force
		elif target_body is RigidBody3D:
			target_body.apply_central_impulse(push_direction * final_force)'''

new_apply = '''	if final_force >= minimum_force_threshold:
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
	_apply_physics(push_direction, final_force)'''

if 'rpc_id' not in content:
    content = content.replace(old_apply, new_apply)
    with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
        f.write(content)
print("Knockback RPC restored")
