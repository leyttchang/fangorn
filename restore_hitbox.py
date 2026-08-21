# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# REGLE D'OR DU RESEAU : Seul l'ordinateur qui GERE cette entit a le droit de valider le coup !
	if not get_parent().is_multiplayer_authority():
		return''', '')

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Hitbox restored")
