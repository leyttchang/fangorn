# -*- coding: utf-8 -*-
import re

for filepath in ['Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd']:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace connection in actor_setup
    content = content.replace('''hitbox.hit_received.connect(_on_hit_received)
		print("[AGGRO SETUP] Hitbox trouve et connecte sur ", name)
	else:
		push_error("[AGGRO SETUP] HitboxComponent INTROUVABLE sur ", name)''', '''hitbox.aggro_requested.connect(_on_aggro_requested)
	else:
		pass''')
		
    content = content.replace('''hitbox.hit_received.connect(_on_hit_received)''', '''hitbox.aggro_requested.connect(_on_aggro_requested)''')

    # Replace _on_hit_received entirely
    new_func = '''func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	_change_target_delayed(attacker)

func _change_target_delayed(new_target: Node3D) -> void:'''

    pattern = re.compile(r'func _on_hit_received\(.*?func _change_target_delayed\(new_target: Node3D\) -> void:', re.DOTALL)
    content = pattern.sub(new_func, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
