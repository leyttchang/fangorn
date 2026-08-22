# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/player.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''func _on_died() -> void:
	print("mort")
	
	# On rcupre le Game Over s'il existe et on l'affiche !
	var game_over = get_node_or_null("GameOverText")
	if game_over != null and is_multiplayer_authority():
		game_over.afficher_game_over()
'''

content = content.replace('''func _on_died() -> void:
	print("mort")''', replacement)

with open('Y:/Fangorn/fangorn/character/player.gd', 'w', encoding='utf-8') as f:
    f.write(content)
