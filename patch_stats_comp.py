import os

path = 'Y:/Fangorn/fangorn/components/StatsComponent.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_stats = '''\t_stats["xp_reward"] = Stat.new(starting_stats.xp_reward)
\t_stats["fire_resistance"] = Stat.new(starting_stats.fire_resistance)
\t_stats["ice_resistance"] = Stat.new(starting_stats.ice_resistance)
\t_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)'''

content = content.replace('\t_stats["xp_reward"] = Stat.new(starting_stats.xp_reward)', new_stats)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
