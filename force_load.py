# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# 1. Filtre des sorts : On ne garde QUE ceux que le joueur n'a PAS encore d?bloqu?s
	var available_locked_spells: Array[AbilityData] = []''', '''	# S?curit? : Si le r?seau a vid? l'array, on le recharge de force
	if all_possible_spells.is_empty():
		_auto_load_default_spells()

	# 1. Filtre des sorts : On ne garde QUE ceux que le joueur n'a PAS encore d?bloqu?s
	var available_locked_spells: Array[AbilityData] = []''')

with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Skill chest force load patched")
