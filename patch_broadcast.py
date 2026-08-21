# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

if 'rpc("_rpc_broadcast_damage", final_damage)' not in content:
    content = content.replace('''	# 4. On applique les d?g?ts
	current_health -= final_damage
	damage_taken.emit(final_damage)''', '''	# 4. On applique les d?g?ts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	rpc("_rpc_broadcast_damage", final_damage)''')
	
    content += '''

@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_damage(final_damage: float) -> void:
	damage_taken.emit(final_damage)
'''

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Broadcast damage added")
