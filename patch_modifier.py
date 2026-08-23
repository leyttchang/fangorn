import os

path = 'Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/stat_modifier_data.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_enum = '@export_enum("max_health", "max_mana", "mana_regen", "armor", "flat_physical_damage", "physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "cd_red", "area_of_effect", "movement_speed", "knockback_power", "knockback_resistance", "casting_speed", "xp_reward") var stat_name: String = "max_health"'
new_enum = '@export_enum("max_health", "max_mana", "mana_regen", "armor", "flat_physical_damage", "physical_damage", "magic_damage", "fire_damage", "ice_damage", "lightning_damage", "attack_speed", "cd_red", "area_of_effect", "movement_speed", "knockback_power", "knockback_resistance", "casting_speed", "xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance") var stat_name: String = "max_health"'

content = content.replace(old_enum, new_enum)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
