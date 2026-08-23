import os

path = 'Y:/Fangorn/fangorn/components/StatsComponent.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
\tvar stat = get_stat(stat_name)
\tif stat != null:'''

new_logic = '''func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
\tvar stat = get_stat(stat_name)
\tif stat == null:
\t\tstat = Stat.new(0.0) # Valeur de base a 0.0 par defaut
\t\t_stats[stat_name] = stat
\t\t
\tif stat != null:'''

content = content.replace(old_logic, new_logic)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
