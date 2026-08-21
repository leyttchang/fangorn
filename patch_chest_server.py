# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/chest_spawner.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func _on_wave_completed(wave_number: int) -> void:\n', 'func _on_wave_completed(wave_number: int) -> void:\n\tif not multiplayer.is_server(): return\n')

with open('Y:/Fangorn/fangorn/objet/chest/chest_spawner.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Chest spawner restricted to server')
