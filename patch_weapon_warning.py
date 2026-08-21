# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/item/armes/weapon.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	else:
		push_warning(name + " n'a pas de WeaponItem (.tres) assign? !")''', '''	else:
		# On ?vite de spammer le warning pour les clones r?seau (ils n'ont pas besoin des stats)
		if attack_component != null and attack_component.is_active_for_network:
			push_warning(name + " n'a pas de WeaponItem (.tres) assign? !")''')

with open('Y:/Fangorn/fangorn/item/armes/weapon.gd', 'w', encoding='utf-8') as f:
    f.write(content)
