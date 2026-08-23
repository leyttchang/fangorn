import os

# 1. Revert StatsComponent dynamic stat creation
path_comp = 'Y:/Fangorn/fangorn/components/StatsComponent.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

old_logic = '''func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
\tvar stat = get_stat(stat_name)
\tif stat == null:
\t\tstat = Stat.new(0.0) # Valeur de base a 0.0 par defaut
\t\t_stats[stat_name] = stat
\t\t
\tif stat != null:'''

new_logic = '''func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
\tvar stat = get_stat(stat_name)
\tif stat != null:'''

content_comp = content_comp.replace(old_logic, new_logic)

# 2. Add damage_taken_multiplier to StatsComponent _ready
init_logic = '''\t_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)
\t_stats["damage_taken_multiplier"] = Stat.new(starting_stats.damage_taken_multiplier)'''
content_comp = content_comp.replace('\t_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)', init_logic)

with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)


# 3. Add to EntityStats
path_entity = 'Y:/Fangorn/fangorn/scripts/stats/entity_stats.gd'
with open(path_entity, 'r', encoding='utf-8') as f:
    content_entity = f.read()

new_export = '''@export var lightning_resistance: float = 0.0
@export var damage_taken_multiplier: float = 0.0'''
content_entity = content_entity.replace('@export var lightning_resistance: float = 0.0', new_export)

with open(path_entity, 'w', encoding='utf-8') as f:
    f.write(content_entity)

print("Patch formel reussi !")
