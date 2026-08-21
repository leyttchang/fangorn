# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/smart_spawner/smart_spawner.gd', 'r', encoding='utf-8') as f:
    content = f.read()

insert = '''func _ready() -> void:
	if not multiplayer.is_server(): return
'''

content = content.replace('func _ready() -> void:\n', insert)

with open('Y:/Fangorn/fangorn/character/enemie/smart_spawner/smart_spawner.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("smart_spawner restricted")
