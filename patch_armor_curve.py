import os

path = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''\t\t\tvar armor = max(stats.get_stat_value("armor"), 0.0)
\t\t\tvar armor_reduction = 0.0
\t\t\tif armor_curve != null:
\t\t\t\tvar armor_x = min(armor / max_expected_armor, 1.0)
\t\t\t\tarmor_reduction = armor_curve.sample(armor_x)
\t\t\tdmg_phys *= (1.0 - armor_reduction)'''

new_logic = '''\t\t\tvar armor = max(stats.get_stat_value("armor"), 0.0)
\t\t\tvar armor_reduction = 0.0
\t\t\tif armor_curve != null:
\t\t\t\t# La courbe de base X va de 0 a 5. Donc on divise par 100.
\t\t\t\t# (Ex: 50 armure = X:0.5 -> 30% reduction)
\t\t\t\tvar armor_x = armor / 100.0
\t\t\t\tarmor_reduction = armor_curve.sample(armor_x)
\t\t\tdmg_phys *= (1.0 - armor_reduction)'''

content = content.replace(old_logic, new_logic)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
