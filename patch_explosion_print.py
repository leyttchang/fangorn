# -*- coding: utf-8 -*-
import os

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('print("--- 3. DA©gA¢ts de l\'explosion rA©glA©s sur : ", explosion.damage, " ---")', 'print("--- 3. Degats mis a jour ---")')
content = content.replace('print("--- 3. D?g?ts de l\'explosion r?gl?s sur : ", explosion.damage, " ---")', 'print("--- 3. Degats mis a jour ---")')
content = content.replace('explosion.damage', 'explosion.base_damage')

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch explosion print applique !")
