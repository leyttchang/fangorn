# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

insert = '''	if multiplayer.is_server():
		# Sync la position aux clients qui rejoignent ou au spawn
		rpc("_rpc_sync_pos", global_position, global_rotation)

@rpc("authority", "call_local", "reliable")
func _rpc_sync_pos(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	global_rotation = rot
'''

if '_rpc_sync_pos' not in content:
    content = content.replace('func _ready() -> void:\n', 'func _ready() -> void:\n' + insert)
    with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Chest position synced")
