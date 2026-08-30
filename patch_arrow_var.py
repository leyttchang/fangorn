import re

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''	if is_character:
		# On previent tous les clients de jouer le sang et cacher la fleche
		var target_path = body.get_path() if is_instance_valid(body) else NodePath("")
		rpc("_rpc_play_character_impact", target_path)''',
'''	if is_character:
		# On previent tous les clients de jouer le sang et cacher la fleche
		var target_path = NodePath("")
		if is_instance_valid(target):
			var entity = target.owner if target.owner != null else target.get_parent()
			target_path = entity.get_path() if is_instance_valid(entity) else target.get_path()
			
		rpc("_rpc_play_character_impact", target_path)'''
)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
