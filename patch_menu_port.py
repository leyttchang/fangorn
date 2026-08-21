# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/lvl/starting_menu.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func _on_join_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1" # Si vide, on se connecte a soi-mame (pour tester)
		
	var error = peer.create_client(ip, PORT)''', '''func _on_join_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var input_text = ip_input.text.strip_edges()
	var ip = input_text
	var target_port = PORT
	
	if input_text == "":
		ip = "127.0.0.1"
	elif ":" in input_text:
		var parts = input_text.split(":")
		ip = parts[0]
		target_port = parts[1].to_int()
		
	var error = peer.create_client(ip, target_port)''')

with open('Y:/Fangorn/fangorn/lvl/starting_menu.gd', 'w', encoding='utf-8') as f:
    f.write(content)
