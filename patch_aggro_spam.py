# -*- coding: utf-8 -*-
import re

for filepath in ['Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd']:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_func = '''var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false

func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	
	# On mmorise le dernier qui a frapp
	_pending_attacker = attacker
	
	# Si on ne compte pas dj jusqu' 1 seconde, on lance le chrono !
	if not _is_waiting_for_aggro:
		_is_waiting_for_aggro = true
		await get_tree().create_timer(1.0).timeout
		
		if not is_instance_valid(self) or current_state == State.DEAD: return
		
		target = _pending_attacker
		_target_update_timer = 0.0
		_is_waiting_for_aggro = false'''

    pattern = re.compile(r'func _on_aggro_requested\(.*?func _change_target_delayed\(new_target: Node3D\) -> void:\n\tawait get_tree\(\)\.create_timer\(1\.0\)\.timeout\n\t# Si le monstre est mort ou effac pendant ce temps, on annule\n\tif not is_instance_valid\(self\) or current_state == State\.DEAD: return\n\t\n\ttarget = new_target\n\t_target_update_timer = 0\.0', re.DOTALL)
    content = pattern.sub(new_func, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
