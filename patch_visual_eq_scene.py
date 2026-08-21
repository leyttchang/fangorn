# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		if get_parent().is_multiplayer_authority():
			var path = ""
			if item != null:
				path = item.resource_path
			rpc("_rpc_update_visual_weapon", path)''', '''		if get_parent().is_multiplayer_authority():
			var path = ""
			if item != null and item.get("weapon_scene") != null:
				path = item.weapon_scene.resource_path
			rpc("_rpc_update_visual_weapon", path)''')

content = content.replace('''func _on_peer_connected(peer_id: int) -> void:
	if equipment_component != null:
		var item = equipment_component.equipped_items.get("main_hand")
		var path = ""
		if item != null:
			path = item.resource_path
		rpc_id(peer_id, "_rpc_update_visual_weapon", path)''', '''func _on_peer_connected(peer_id: int) -> void:
	if equipment_component != null:
		var item = equipment_component.equipped_items.get("main_hand")
		var path = ""
		if item != null and item.get("weapon_scene") != null:
			path = item.weapon_scene.resource_path
		rpc_id(peer_id, "_rpc_update_visual_weapon", path)''')

content = content.replace('''	# 3. On charge la ressource envoy?e par le r?seau
	var item = load(resource_path)
	if item == null or item.get("weapon_scene") == null:
		return
		
	# 4. On cr?e la nouvelle arme 3D
	var weapon_instance = item.weapon_scene.instantiate()
	
	if weapon_instance is Weapon:
		weapon_instance.weapon_stats = item''', '''	# 3. On charge la scne envoy?e par le r?seau
	var weapon_scene = load(resource_path)
	if weapon_scene == null:
		return
		
	# 4. On cr?e la nouvelle arme 3D
	var weapon_instance = weapon_scene.instantiate()
	
	# Pas besoin de weapon_stats pour le visuel des autres joueurs
	# (car leur AttackComponent sera d?sactiv? de toute faon)''')

with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'w', encoding='utf-8') as f:
    f.write(content)
