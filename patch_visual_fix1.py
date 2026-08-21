# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if "if slot_name == \"main_hand\":" in line:
        new_lines.append("\t\t# Envoi r?seau !\n")
        new_lines.append("\t\tif multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():\n")
        new_lines.append("\t\t\tvar path = \"\"\n")
        new_lines.append("\t\t\tif item != null and item.get(\"weapon_scene\") != null:\n")
        new_lines.append("\t\t\t\tpath = item.weapon_scene.resource_path\n")
        new_lines.append("\t\t\trpc(\"_rpc_update_visual_weapon\", path)\n")

with open('Y:/Fangorn/fangorn/components/visual_equipment_manager.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
