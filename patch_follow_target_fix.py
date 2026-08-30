import re

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''	print("[DEBUG] Blood particle script: ", blood.get_script())
	if blood.has_method("play_effect"):''',
'''	if blood.has_method("set_follow_target") and not target_path.is_empty():
		var target_node = get_node_or_null(target_path)
		blood.set_follow_target(target_node)
		
	if blood.has_method("play_effect"):'''
)

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
