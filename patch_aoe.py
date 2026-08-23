import os

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tglobal_bonus += (caster_stats.get_stat_value("magic_damage") - 1.0)
\t\t\tif is_aoe:
\t\t\t\tglobal_bonus += (caster_stats.get_stat_value("area_of_effect") - 1.0)'''

new_block = '''\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tvar mag = caster_stats.get_stat_value("magic_damage")
\t\t\t\tif mag == 0.0: mag = 1.0
\t\t\t\tglobal_bonus += (mag - 1.0)
\t\t\tif is_aoe:
\t\t\t\tvar aoe = caster_stats.get_stat_value("aoe_damage")
\t\t\t\tif aoe == 0.0: aoe = 1.0
\t\t\t\tglobal_bonus += (aoe - 1.0)'''

content = content.replace(old_block, new_block)

# Protect elements too just in case
def protect_stat(stat_name):
    return f'''var val_{stat_name} = caster_stats.get_stat_value("{stat_name}")
\t\t\tif val_{stat_name} == 0.0: val_{stat_name} = 1.0
\t\t\tvar {stat_name.split('_')[0]}_bonus = global_bonus + (val_{stat_name} - 1.0)'''

content = content.replace('var phys_bonus = global_bonus + (caster_stats.get_stat_value("physical_damage") - 1.0)', protect_stat('physical_damage'))
content = content.replace('var fire_bonus = global_bonus + (caster_stats.get_stat_value("fire_damage") - 1.0)', protect_stat('fire_damage'))
content = content.replace('var ice_bonus = global_bonus + (caster_stats.get_stat_value("ice_damage") - 1.0)', protect_stat('ice_damage'))
content = content.replace('var lightning_bonus = global_bonus + (caster_stats.get_stat_value("lightning_damage") - 1.0)', protect_stat('lightning_damage'))

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch AoE applique !")
