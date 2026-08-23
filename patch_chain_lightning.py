# -*- coding: utf-8 -*-
import os

# --- REVERT LIGHTNING STRIKE ---
path_ls = 'Y:/Fangorn/fangorn/scripts/abilities/lightning_strike/lightning_strike.gd'
with open(path_ls, 'r', encoding='utf-8') as f:
    content_ls = f.read()

old_block = '''\tawait get_tree().create_timer(duration_on_ground).timeout
\tif has_node("AttackComponent"):
\t\tvar attack = 
\t\tvar hit_count = 0
\t\tfor entity in attack.hit_entities:
\t\t\tif entity is HitboxComponent:
\t\t\t\thit_count += 1
\t\tprint("? Lightning Strike a touche ", hit_count, " monstres !")
\t\tattack.queue_free()'''

new_block = '''\tawait get_tree().create_timer(duration_on_ground).timeout
\tif has_node("AttackComponent"):
\t\t.queue_free()'''

content_ls = content_ls.replace(old_block, new_block)
with open(path_ls, 'w', encoding='utf-8') as f:
    f.write(content_ls)


# --- PATCH CHAIN LIGHTNING ---
path_cl = 'Y:/Fangorn/fangorn/scripts/abilities/chain_lightning/chain_lightning.gd'
with open(path_cl, 'r', encoding='utf-8') as f:
    content_cl = f.read()

# We need to find where the bounces end.
# Chain lightning has a ounces_done variable and stops.
print("Reading chain lightning...")
