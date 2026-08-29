import re

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''	if blood.has_method("play_effect"):
		blood.play_effect()
	else:
		print("[ERROR] Blood particle does NOT have play_effect method!")''',
'''	print("[DEBUG] Blood particle script: ", blood.get_script())
	if blood.has_method("play_effect"):
		blood.play_effect()
	else:
		print("[ERROR] Blood particle does NOT have play_effect method!")'''
)

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
