# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if new_target != null:
		_change_target_delayed(new_target)''', '''	if new_target != null:
		print("[AGGRO] Monstre frapp par : ", new_target.name)
		_change_target_delayed(new_target)''')

content = content.replace('''func _change_target_delayed(new_target: Node3D) -> void:
	await get_tree().create_timer(1.0).timeout
	# Si le monstre est mort ou effac pendant ce temps, on annule
	if not is_instance_valid(self) or current_state == State.DEAD: return
	
	target = new_target
	_target_update_timer = 0.0''', '''func _change_target_delayed(new_target: Node3D) -> void:
	await get_tree().create_timer(1.0).timeout
	# Si le monstre est mort ou effac pendant ce temps, on annule
	if not is_instance_valid(self) or current_state == State.DEAD: return
	
	print("[AGGRO] Changement de cible pour : ", new_target.name)
	target = new_target
	_target_update_timer = 0.0''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'w', encoding='utf-8') as f:
    f.write(content)
