# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func _ready() -> void:
	if equipment_component != null:
		# On ?coute quand l'?quipement change !
		equipment_component.equipment_changed.connect(_on_equipment_changed)''', '''func _ready() -> void:
	if equipment_component != null:
		# On ?coute quand l'?quipement change !
		equipment_component.equipment_changed.connect(_on_equipment_changed)
		
	# Quand un nouveau joueur rejoint, on doit lui dire quelle arme on porte !
	if multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
		multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(peer_id: int) -> void:
	if equipment_component != null:
		var item = equipment_component.equipped_items.get("main_hand")
		var path = ""
		if item != null:
			path = item.resource_path
		rpc_id(peer_id, "_rpc_update_visual_weapon", path)''')

with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'w', encoding='utf-8') as f:
    f.write(content)
