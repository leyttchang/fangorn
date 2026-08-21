# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if "equipment_component.equipment_changed.connect(_on_equipment_changed)" in line:
        new_lines.append("\t\tif multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():\n")
        new_lines.append("\t\t\tmultiplayer.peer_connected.connect(_on_peer_connected)\n")

# Add the peer_connected func
if "func _on_peer_connected" not in "".join(lines):
    new_lines.append("\nfunc _on_peer_connected(peer_id: int) -> void:\n")
    new_lines.append("\tif equipment_component != null:\n")
    new_lines.append("\t\tvar item = equipment_component.equipped_items.get(\"main_hand\")\n")
    new_lines.append("\t\tvar path = \"\"\n")
    new_lines.append("\t\tif item != null and item.get(\"weapon_scene\") != null:\n")
    new_lines.append("\t\t\tpath = item.weapon_scene.resource_path\n")
    new_lines.append("\t\trpc_id(peer_id, \"_rpc_update_visual_weapon\", path)\n")

with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
