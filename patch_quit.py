# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/player.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace get_tree().quit() with something else in _on_died
old_died = '''func _on_died() -> void:
	print("mort")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()'''

new_died = '''func _on_died() -> void:
	print("mort")
	# Temporairement, on empeche le jeu de se fermer en multi !
	# await get_tree().create_timer(2.0).timeout
	# get_tree().quit()
'''

content = content.replace(old_died, new_died)

with open('Y:/Fangorn/fangorn/character/player.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed get_tree().quit()")
