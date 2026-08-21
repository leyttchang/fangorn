# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace local signal emissions with RPC call
content = content.replace('damage_taken.emit(final_damage)', 'rpc("_rpc_broadcast_damage", final_damage, current_health)')
content = content.replace('died.emit()', '') # We will emit died in the broadcast
content = content.replace('health_changed.emit(current_health, max_hp)', '')

rpc_broadcast = '''
@rpc("authority", "call_local", "reliable")
func _rpc_broadcast_damage(amount: float, new_health: float) -> void:
	current_health = new_health
	damage_taken.emit(amount)
	
	var max_hp = stats_component.get_stat_value("max_health")
	health_changed.emit(current_health, max_hp)
	
	if current_health <= 0:
		died.emit()
'''

if '_rpc_broadcast_damage' not in content:
    content += rpc_broadcast

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Patch applied')
