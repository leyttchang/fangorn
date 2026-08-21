# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if possible_bases.is_empty() or all_possible_affixes.is_empty():
		print("Attention: Le coffre n'a pas de bases ou d'affixes configur?s dans l'inspecteur !")
		return''', '''	if possible_bases.is_empty() or all_possible_affixes.is_empty():
		possible_bases = GameData.get_all_bases().duplicate()
		all_possible_affixes = GameData.get_all_affixes()''')

with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Item chest force load patched")
