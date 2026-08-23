import os

path = 'Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/stat_modifier_data.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_enum = '"xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance"'
new_enum = '"xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance", "damage_taken_multiplier"'

content = content.replace(old_enum, new_enum)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
