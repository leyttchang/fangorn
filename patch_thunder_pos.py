import re

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''func execute(caster: Node3D, target_data: Dictionary) -> void:
\tmon_lanceur = caster
\tglobal_position = caster.global_position'''

content = content.replace('func execute(caster: Node3D, target_data: Dictionary) -> void:\n\tmon_lanceur = caster', replacement)

with open('Y:/Fangorn/fangorn/scripts/abilities/thunder_aspect/thunder_aspect.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched thunder_aspect global_position")
