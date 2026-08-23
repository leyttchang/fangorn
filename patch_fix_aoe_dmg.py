import os

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('global_bonus += _get_stat_bonus(caster_stats, "area_of_effect")', 'global_bonus += _get_stat_bonus(caster_stats, "aoe_damage")')

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fix AoE damage applique !")
