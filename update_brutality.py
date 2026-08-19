with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/brutality_keystone.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Remove mana tracking
content = content.replace('if stat_name in ["max_mana", "mana_regen", "fire_damage", "ice_damage", "lightning_damage"]:', 'if stat_name in ["fire_damage", "ice_damage", "lightning_damage"]:')
content = content.replace('\t_force_stat("max_mana", 0.0)\n\t_force_stat("mana_regen", 0.0)\n\t_force_stat("fire_damage", 1.0)\n\t_force_stat("ice_damage", 1.0)\n\t_force_stat("lightning_damage", 1.0)', '\t_force_stat("fire_damage", 0.0)\n\t_force_stat("ice_damage", 0.0)\n\t_force_stat("lightning_damage", 0.0)')

# Remove max_mana and mana_regen from exit_tree
content = content.replace('\t\tstats.remove_modifier_by_source("brutality_max_mana")\n\t\tstats.remove_modifier_by_source("brutality_mana_regen")\n', '')

with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/brutality_keystone.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated brutality keystone mana/elemental logic")
