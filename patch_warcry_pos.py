import re

with open('Y:/Fangorn/fangorn/scripts/abilities/Warcry/warcry.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''func execute(caster: Node3D, target_data: Dictionary) -> void:
\tmon_lanceur = caster
\t
\t# TRES IMPORTANT : On téléporte la scène du sort sur le joueur !
\t# Sinon les particules vont apparaître au milieu de la map (0,0,0)
\tglobal_position = caster.global_position'''

content = content.replace('func execute(caster: Node3D, target_data: Dictionary) -> void:\n\tmon_lanceur = caster', replacement)

with open('Y:/Fangorn/fangorn/scripts/abilities/Warcry/warcry.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched global_position")
