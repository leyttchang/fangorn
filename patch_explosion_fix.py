# -*- coding: utf-8 -*-
import os

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('explosion.base_damage_physical', 'explosion.damage_physical')
content = content.replace('explosion.base_damage_fire', 'explosion.damage_fire')
content = content.replace('explosion.base_damage_ice', 'explosion.damage_ice')
content = content.replace('explosion.base_damage_lightning', 'explosion.damage_lightning')

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch explosion applique !")
