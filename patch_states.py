# -*- coding: utf-8 -*-
import os, re

def patch_change_state(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the function definition
    if 'func change_state(new_state: State) -> void:' in content and 'func _rpc_apply_state' not in content:
        # Replace the function signature with _rpc_apply_state, taking an int
        # But we need to keep the match logic.
        new_logic = '''func change_state(new_state: State) -> void:
	if is_multiplayer_authority():
		rpc("_rpc_apply_state", new_state)

@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(new_state: int) -> void:'''
        
        content = content.replace('func change_state(new_state: State) -> void:', new_logic)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

patch_change_state('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd')
patch_change_state('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd')

print('Animation states patched')
