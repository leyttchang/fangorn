# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# Si ce n'est pas attach un personnage
	if p == null:
		if get_multiplayer_authority() != 1:
			# Si l'autorit a t force manuellement (ex: un sort lanc par un client)
			is_active_for_network = is_multiplayer_authority()
		else:
			# Par dfaut (pics, flches de mobs), le serveur gre
			is_active_for_network = multiplayer.is_server()''', '''	# Si ce n'est pas attach un personnage (ex: sort instanci, pic)
	if p == null:
		if has_meta("caster_authority"):
			var caster_id = get_meta("caster_authority")
			if caster_id != 1:
				is_active_for_network = (caster_id == multiplayer.get_unique_id())
			else:
				is_active_for_network = multiplayer.is_server()
		else:
			# Par dfaut (pics, flches de mobs sans meta), le serveur gre
			is_active_for_network = multiplayer.is_server()''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
