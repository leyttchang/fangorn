# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/player.gd', 'r', encoding='utf-8') as f:
    content = f.read()

insert = '''	if not is_multiplayer_authority():
		# Cacher toute l'UI du joueur si ce n'est pas NOTRE joueur !
		for child in get_children():
			if child is CanvasLayer:
				child.visible = false
'''

# We inject this into _ready if it's not there
if "child is CanvasLayer" not in content:
    content = content.replace('func _ready() -> void:\n', 'func _ready() -> void:\n' + insert)
    with open('Y:/Fangorn/fangorn/character/player.gd', 'w', encoding='utf-8') as f:
        f.write(content)
    print("UI hiding patched")
