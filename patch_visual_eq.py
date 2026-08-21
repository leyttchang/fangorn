# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func _on_equipment_changed(slot_name: String, item: ItemData) -> void:
	# On ne r?agit que si c'est la main droite
	if slot_name == "main_hand":
		
		# 1. On d?truit l'ancienne arme (s'il y en a une)''', '''func _on_equipment_changed(slot_name: String, item: ItemData) -> void:
	# On ne r?agit que si c'est la main droite
	if slot_name == "main_hand":
		
		# On pr?vient les autres joueurs de notre changement d'arme !
		if get_parent().is_multiplayer_authority():
			var path = ""
			if item != null:
				path = item.resource_path
			rpc("_rpc_update_visual_weapon", path)
			
		# 1. On d?truit l'ancienne arme (s'il y en a une)''')

rpc_code = '''
# ==========================================
# GESTION RESEAU DE L'APPARENCE DE L'ARME
# ==========================================
@rpc("any_peer", "call_remote", "reliable")
func _rpc_update_visual_weapon(resource_path: String) -> void:
	# 1. On d?truit l'ancienne arme
	for child in main_droite.get_children():
		child.queue_free()
		
	# 2. Si mains nues
	if resource_path == "":
		return
		
	# 3. On charge la ressource envoy?e par le r?seau
	var item = load(resource_path)
	if item == null or item.get("weapon_scene") == null:
		return
		
	# 4. On cr?e la nouvelle arme 3D
	var weapon_instance = item.weapon_scene.instantiate()
	
	if weapon_instance is Weapon:
		weapon_instance.weapon_stats = item
		
	main_droite.add_child(weapon_instance)
'''

content += rpc_code

with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'w', encoding='utf-8') as f:
    f.write(content)
