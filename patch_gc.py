# -*- coding: utf-8 -*-

def inject_gc(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add the variables and RPC
    gc_code = '''
var players_looted: Array[int] = []

func _notify_looted() -> void:
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "_rpc_chest_looted", my_id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_chest_looted(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if not players_looted.has(peer_id):
		players_looted.append(peer_id)
		
	var total_players = multiplayer.get_peers().size() + 1
	if players_looted.size() >= total_players:
		queue_free()
'''
    if '_rpc_chest_looted' not in content:
        content += gc_code

    # Call it where we hide the chest
    old_hide = '''		var static_body = get_node_or_null("StaticBody3D")
		if static_body:
			static_body.queue_free()'''
			
    new_hide = '''		var static_body = get_node_or_null("StaticBody3D")
		if static_body:
			static_body.queue_free()
			
		_notify_looted()'''
		
    content = content.replace(old_hide, new_hide)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

inject_gc('Y:/Fangorn/fangorn/objet/chest/chest.gd')
inject_gc('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd')
print("Garbage collection patched")
