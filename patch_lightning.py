# -*- coding: utf-8 -*-
import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/lightning_strike/lightning_strike.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''\tawait get_tree().create_timer(duration_on_ground).timeout
\tif has_node("AttackComponent"):
\t\t.queue_free()'''

new_block = '''\tawait get_tree().create_timer(duration_on_ground).timeout
\tif has_node("AttackComponent"):
\t\tvar attack = 
\t\tvar hit_count = 0
\t\tfor entity in attack.hit_entities:
\t\t\tif entity is HitboxComponent:
\t\t\t\thit_count += 1
\t\tprint("? Lightning Strike a touche ", hit_count, " monstres !")
\t\tattack.queue_free()'''

content = content.replace(old_block, new_block)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
