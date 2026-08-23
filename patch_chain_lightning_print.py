# -*- coding: utf-8 -*-
import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/chain_lightning/chain_lightning.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''\t_process_bounce(initial_target, start_node, hit_targets)
\t
\t# Le sort n'a plus besoin d'exister en tant que n\u0153ud, les lignes g\u017erent leur propre dur\u01f8e de vie
\tqueue_free()'''

new_block = '''\t_process_bounce(initial_target, start_node, hit_targets)
\t
\tprint("? Chain Lightning a touche ", hit_targets.size(), " monstres !")
\t
\t# Le sort n'a plus besoin d'exister en tant que noeud, les lignes gerent leur propre duree de vie
\tqueue_free()'''

content = content.replace(old_block, new_block)

# Since unicode might fail, I'll use a safer replace
content = content.replace('\t_process_bounce(initial_target, start_node, hit_targets)\n\t\n\t#', '\t_process_bounce(initial_target, start_node, hit_targets)\n\tprint("? Chain Lightning a touche ", hit_targets.size(), " monstres !")\n\t#')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
