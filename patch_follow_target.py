import re

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''			_spawn_blood(impact_point, impact_normal)''',
'''			var target_path = hit_target.get_path() if is_instance_valid(hit_target) else NodePath("")
			_spawn_blood(impact_point, impact_normal, target_path)'''
)

content = content.replace(
'''func _spawn_blood(impact_point: Vector3, impact_normal: Vector3) -> void:
	# On s'assure de ne l'appeler que si on est le joueur qui donne le coup
	if not is_multiplayer_authority():
		return
	
	# call_local = on l'execute sur NOUS (le tireur) ET sur tous les autres joueurs
	rpc("_rpc_spawn_blood", impact_point, impact_normal)

@rpc("authority", "call_local", "unreliable")
func _rpc_spawn_blood(impact_point: Vector3, impact_normal: Vector3) -> void:''',
'''func _spawn_blood(impact_point: Vector3, impact_normal: Vector3, target_path: NodePath) -> void:
	# On s'assure de ne l'appeler que si on est le joueur qui donne le coup
	if not is_multiplayer_authority():
		return
	
	# call_local = on l'execute sur NOUS (le tireur) ET sur tous les autres joueurs
	rpc("_rpc_spawn_blood", impact_point, impact_normal, target_path)

@rpc("authority", "call_local", "unreliable")
func _rpc_spawn_blood(impact_point: Vector3, impact_normal: Vector3, target_path: NodePath = NodePath("")) -> void:'''
)

content = content.replace(
'''		blood.look_at(impact_point + impact_normal, up_dir)
		
	if blood.has_method("play_effect"):''',
'''		blood.look_at(impact_point + impact_normal, up_dir)
		
	if blood.has_method("set_follow_target") and not target_path.is_empty():
		var target_node = get_node_or_null(target_path)
		blood.set_follow_target(target_node)
		
	if blood.has_method("play_effect"):'''
)

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
