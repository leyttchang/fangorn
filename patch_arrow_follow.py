import re

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''	if is_character:
		# On previent tous les clients de jouer le sang et cacher la fleche
		rpc("_rpc_play_character_impact")''',
'''	if is_character:
		# On previent tous les clients de jouer le sang et cacher la fleche
		var target_path = body.get_path() if is_instance_valid(body) else NodePath("")
		rpc("_rpc_play_character_impact", target_path)'''
)

content = content.replace(
'''@rpc("authority", "call_local", "reliable")
func _rpc_play_character_impact() -> void:''',
'''@rpc("authority", "call_local", "reliable")
func _rpc_play_character_impact(target_path: NodePath = NodePath("")) -> void:'''
)

content = content.replace(
'''				blood.look_at(global_position + impact_normal, up_dir)
				
			if blood.has_method("play_effect"):''',
'''				blood.look_at(global_position + impact_normal, up_dir)
				
			if blood.has_method("set_follow_target") and not target_path.is_empty():
				var target_node = get_node_or_null(target_path)
				blood.set_follow_target(target_node)
				
			if blood.has_method("play_effect"):'''
)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
