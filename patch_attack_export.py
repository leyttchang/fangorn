import os

path = 'Y:/Fangorn/fangorn/components/attack_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_exports = '''@export var is_projectile: bool = false

@export_group("Status Effects")
@export var status_effects_to_apply: Array[StatusEffectApplication] = []'''

content = content.replace('@export var is_projectile: bool = false', new_exports)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
