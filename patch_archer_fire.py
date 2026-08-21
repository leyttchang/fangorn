# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func fire_arrow() -> void:
	if arrow_scene == null:''', '''func fire_arrow() -> void:
	if not multiplayer.is_server(): return
	if arrow_scene == null:''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Archer fire arrow patched")
