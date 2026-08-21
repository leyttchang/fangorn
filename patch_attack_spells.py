# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# Si ce n'est pas attach un personnage, le serveur est l'autorit
	if p == null:
		is_active_for_network = multiplayer.is_server()''', '''	# Si ce n'est pas attach un personnage
	if p == null:
		if get_multiplayer_authority() != 1:
			# Si l'autorit a t force manuellement (ex: un sort lanc par un client)
			is_active_for_network = is_multiplayer_authority()
		else:
			# Par dfaut (pics, flches de mobs), le serveur gre
			is_active_for_network = multiplayer.is_server()''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("AttackComponent updated for spells")
