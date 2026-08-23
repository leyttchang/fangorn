# -*- coding: utf-8 -*-
import os, re

path = 'Y:/Fangorn/fangorn/scripts/abilities/fireball/old_fireball/fireball.gd'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    content = re.sub(r'attack_component\.damage', 'attack_component.base_damage', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
