# -*- coding: utf-8 -*-
import os

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_block_safe = 'explosion.damage = attack_component.damage * ratio_degat'
new_block_safe = '''explosion.base_damage = attack_component.base_damage * ratio_degat
\t\texplosion.damage_physical = attack_component.damage_physical * ratio_degat
\t\texplosion.damage_fire = attack_component.damage_fire * ratio_degat
\t\texplosion.damage_ice = attack_component.damage_ice * ratio_degat
\t\texplosion.damage_lightning = attack_component.damage_lightning * ratio_degat'''

content = content.replace(old_block_safe, new_block_safe)

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch explosion applique !")
