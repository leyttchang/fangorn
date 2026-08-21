# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb_spawner.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func spawn_dumb() -> void:
	if is_disabled or Dumb == null:
		return''', '''func spawn_dumb() -> void:
	if not multiplayer.is_server(): return
	if is_disabled or Dumb == null:
		return''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb_spawner.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dumb spawner patched")
