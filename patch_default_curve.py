import os

path = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@export var armor_curve: Curve', '@export var armor_curve: Curve = preload("res://components/stats/armor_curve.tres")')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
