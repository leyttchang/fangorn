# -*- coding: utf-8 -*-
import os, re

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'explosion\.damage', 'explosion.base_damage', content)

with open('Y:/Fangorn/fangorn/components/spell_componants/explosion-after_hit_after_hit.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch explosion regex applique !")
