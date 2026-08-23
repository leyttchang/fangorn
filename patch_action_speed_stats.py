import os

# 1. Update Enum in StatModifierData
path_mod = 'Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/stat_modifier_data.gd'
with open(path_mod, 'r', encoding='utf-8') as f:
    content_mod = f.read()

old_enum = '"xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance"'
new_enum = '"xp_reward", "fire_resistance", "ice_resistance", "lightning_resistance", "action_speed"'

content_mod = content_mod.replace(old_enum, new_enum)
with open(path_mod, 'w', encoding='utf-8') as f:
    f.write(content_mod)

# 2. Update EntityStats
path_entity = 'Y:/Fangorn/fangorn/scripts/stats/entity_stats.gd'
with open(path_entity, 'r', encoding='utf-8') as f:
    content_entity = f.read()

old_export = '@export var lightning_resistance: float = 0.0'
new_export = '@export var lightning_resistance: float = 0.0\n@export var action_speed: float = 1.0'

content_entity = content_entity.replace(old_export, new_export)
with open(path_entity, 'w', encoding='utf-8') as f:
    f.write(content_entity)

# 3. Update StatsComponent
path_comp = 'Y:/Fangorn/fangorn/components/StatsComponent.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

init_logic = '''\t_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)
\t_stats["action_speed"] = Stat.new(starting_stats.action_speed)'''

content_comp = content_comp.replace('\t_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)', init_logic)
with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)
