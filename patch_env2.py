# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# Si ce n'est pas attach un personnage, on vrifie si c'est un projectile gr par le serveur
	if p == null and multiplayer.is_server():
		is_active_for_network = true''', '''	if p == null:
		is_active_for_network = true''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("AttackComponent environment hazards fixed")
