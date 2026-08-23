import os

path = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@export var max_expected_armor: float = 200.0', '@export var max_expected_armor: float = 500.0')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
