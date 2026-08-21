# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_use = '''func use(player: CharacterBody3D) -> void:
	if is_open: return
	player_in_range = player
	open_chest()'''

new_use = '''func use(player: CharacterBody3D) -> void:
	if is_open: return
	# On demande au serveur d'ouvrir le coffre pour nous
	rpc_id(1, "_rpc_request_open", player.name)

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_open(player_name: String) -> void:
	if not multiplayer.is_server(): return
	if is_open: return
	
	# Le serveur trouve le joueur qui a fait la demande
	var player_node = get_tree().current_scene.get_node("Players/" + player_name)
	if player_node != null:
		player_in_range = player_node
		open_chest()
'''

if '_rpc_request_open' not in content:
    content = content.replace(old_use, new_use)
    with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Skill chest RPC patched")
