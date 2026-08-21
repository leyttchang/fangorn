# -*- coding: utf-8 -*-
import os

filepath = 'Y:/Fangorn/fangorn/objet/chest/chest_spawner.gd'
if os.path.exists(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    content = content.replace('world.add_child(chest)', 'get_tree().current_scene.get_node("NetworkObjects").add_child(chest, true)')
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print('Chest spawner patched')
