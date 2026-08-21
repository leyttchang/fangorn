# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if p == null:
		is_active_for_network = true''', '''	if p == null and multiplayer.is_server():
		is_active_for_network = true''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("AttackComponent env hazards reverted to server only")
