# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/player.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.5)
content = content.replace('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.5)', 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.2)')

with open('Y:/Fangorn/fangorn/character/player.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
