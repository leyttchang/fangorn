# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Revert use() back to local
content = content.replace('''func use(player: CharacterBody3D) -> void:
	if is_open: return
	# On demande au serveur d'ouvrir le coffre pour nous
	rpc_id(1, "_rpc_request_open", player.name)''', '''func use(player: CharacterBody3D) -> void:
	if is_open: return
	player_in_range = player
	open_chest()''')

# Remove _rpc_request_open entirely
import re
content = re.sub(r'@rpc\("any_peer", "call_local", "reliable"\)\nfunc _rpc_request_open.*?open_chest\(\)\n', '', content, flags=re.DOTALL)

# Replace queue_free() with local hide
content = content.replace('queue_free()', '''# Au lieu de queue_free() qui le d?truit pour tout le monde, on le cache juste localement
	visible = false
	var interact = get_node_or_null("InteractionComponent")
	if interact:
		interact.queue_free()''')

with open('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Skill chest reverted and hide patched")
