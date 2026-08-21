# -*- coding: utf-8 -*-
import os

def fix_script(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the injected RPC
    bad_code = '''	if multiplayer.is_server():
		# Sync la position aux clients qui rejoignent ou au spawn
		rpc("_rpc_sync_pos", global_position, global_rotation)

@rpc("authority", "call_local", "reliable")
func _rpc_sync_pos(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	global_rotation = rot'''
	
    if bad_code in content:
        content = content.replace(bad_code, '')
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

fix_script('Y:/Fangorn/fangorn/objet/chest/chest.gd')
fix_script('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd')
print("Scripts fixed")
