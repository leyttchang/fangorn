# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Restrict take_damage to authority
content = content.replace('''func take_damage(raw_damage: float) -> void:
	if current_health <= 0:''', '''func take_damage(raw_damage: float) -> void:
	if not owner.is_multiplayer_authority(): return
	if current_health <= 0:''')

# 2. Add visual damage broadcast
content = content.replace('''	# 4. On applique les d?g?ts
	current_health -= final_damage
	damage_taken.emit(final_damage)''', '''	# 4. On applique les d?g?ts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	rpc("_rpc_broadcast_damage", final_damage)''')

# 3. Add the RPC function at the end of the file
rpc_func = '''

@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_damage(final_damage: float) -> void:
	damage_taken.emit(final_damage)
'''
content += rpc_func

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Health component completely fixed and restored")
