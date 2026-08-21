# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

insert = '''
	if not owner.is_multiplayer_authority():
		# Ce n'est pas mon entite ! Je demande au proprietaire d'appliquer les degats
		rpc_id(owner.get_multiplayer_authority(), "_rpc_take_damage", raw_damage)
		return
'''

content = re.sub(r'func take_damage\(raw_damage: float\) -> void:\n', 'func take_damage(raw_damage: float) -> void:\n' + insert, content)

rpc = '''

@rpc("any_peer", "call_local", "reliable")
func _rpc_take_damage(raw_damage: float) -> void:
	if owner.is_multiplayer_authority():
		take_damage(raw_damage)
'''

if '_rpc_take_damage' not in content:
    content += rpc

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Patch applied')
