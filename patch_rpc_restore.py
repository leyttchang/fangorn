# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

rpc = '''
@rpc("any_peer", "call_local", "reliable")
func _rpc_take_damage(raw_damage: float) -> void:
	if owner.is_multiplayer_authority():
		take_damage(raw_damage)
'''

if 'func _rpc_take_damage' not in content:
    content += rpc
    
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("RPC take damage restored")
