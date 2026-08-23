import os

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''\t\t\t\t\t\t\tbase_cast_time = 1.0 / weapon.base_attack_speed
\t\t\t\t\t\telse:
\t\t\t\t\t\t\tbase_cast_time = 1.0'''

new_block = '''\t\t\t\t\t\t\tbase_cast_time = 1.0 / weapon.base_attack_speed
\t\t\t\t\t\telse:
\t\t\t\t\t\t\tbase_cast_time = 1.0
\t\t\t\t\t
\t\t\t\t\t# On applique le multiplicateur propre a la competence
\t\t\t\t\tif "weapon_speed_multiplier" in ability and ability.weapon_speed_multiplier > 0.0:
\t\t\t\t\t\tbase_cast_time /= ability.weapon_speed_multiplier'''

content = content.replace(old_block, new_block)

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch skill bar applique !")
