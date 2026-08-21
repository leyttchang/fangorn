# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		if multiplayer.is_server():
			queue_free()''', '''		if is_inside_tree() and multiplayer.is_server():
			queue_free()''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fire arrow is_inside_tree patched")
