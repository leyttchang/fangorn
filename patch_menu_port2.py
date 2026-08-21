# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/lvl/starting_menu.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_join = False
for line in lines:
    if "func _on_join_pressed" in line:
        in_join = True
        new_lines.append("func _on_join_pressed() -> void:\n")
        new_lines.append("\tvar peer = ENetMultiplayerPeer.new()\n")
        new_lines.append("\tvar input_text = ip_input.text.strip_edges()\n")
        new_lines.append("\tvar ip = input_text\n")
        new_lines.append("\tvar target_port = PORT\n\n")
        new_lines.append("\tif input_text == \"\":\n")
        new_lines.append("\t\tip = \"127.0.0.1\"\n")
        new_lines.append("\telif \":\" in input_text:\n")
        new_lines.append("\t\tvar parts = input_text.split(\":\")\n")
        new_lines.append("\t\tip = parts[0]\n")
        new_lines.append("\t\ttarget_port = parts[1].to_int()\n\n")
        new_lines.append("\tif not ip.is_valid_ip_address():\n")
        new_lines.append("\t\tip = IP.resolve_hostname(ip)\n\n")
        new_lines.append("\tvar error = peer.create_client(ip, target_port)\n")
        new_lines.append("\tif error == OK:\n")
        new_lines.append("\t\tmultiplayer.multiplayer_peer = peer\n")
        new_lines.append("\t\tprint(\"Tentative de connexion au serveur \", ip, \":\", target_port)\n")
        new_lines.append("\t\tget_tree().change_scene_to_file(\"res://lvl/game.tscn\")\n")
        new_lines.append("\telse:\n")
        new_lines.append("\t\tprint(\"Erreur lors de la connexion : \", error)\n")
        continue
    if in_join:
        if line.strip() == "" or line.startswith("\t"):
            continue
        else:
            in_join = False
            
    if not in_join:
        new_lines.append(line)

with open('Y:/Fangorn/fangorn/lvl/starting_menu.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
