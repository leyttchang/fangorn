# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('get_tree().current_scene.add_child(new_arrow)', 'get_tree().current_scene.get_node("NetworkObjects").add_child(new_arrow, true)')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Archer patched')
