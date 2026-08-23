# -*- coding: utf-8 -*-
import os

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''\t\t\t# A. Recuperation des bonus globaux (Tags)
\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tglobal_bonus += caster_stats.get_stat_value("magic_damage")
\t\t\tif is_aoe:
\t\t\t\tglobal_bonus += caster_stats.get_stat_value("aoe_damage")
\t\t\t
\t\t\t# B. Repartition sur les elements (Le 1.0 represente les 100% de base)
\t\t\tvar phys_bonus = global_bonus + caster_stats.get_stat_value("physical_damage")
\t\t\tattack_component.damage_physical = (final_base * phys_ratio) * (1.0 + phys_bonus)
\t\t\t
\t\t\tvar fire_bonus = global_bonus + caster_stats.get_stat_value("fire_damage")
\t\t\tattack_component.damage_fire = (final_base * fire_ratio) * (1.0 + fire_bonus)
\t\t\t
\t\t\tvar ice_bonus = global_bonus + caster_stats.get_stat_value("ice_damage")
\t\t\tattack_component.damage_ice = (final_base * ice_ratio) * (1.0 + ice_bonus)
\t\t\t
\t\t\tvar lightning_bonus = global_bonus + caster_stats.get_stat_value("lightning_damage")
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)'''

new_block = '''\t\t\t# A. Recuperation des bonus globaux (Tags)
\t\t\t# Dans un systeme additif, on doit retirer la base (1.0) pour obtenir le BONUS brut !
\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tglobal_bonus += (caster_stats.get_stat_value("magic_damage") - 1.0)
\t\t\tif is_aoe:
\t\t\t\tglobal_bonus += (caster_stats.get_stat_value("area_of_effect") - 1.0)
\t\t\t
\t\t\t# B. Repartition sur les elements (On ajoute les bonus elementaires bruts, puis on remet la base 1.0)
\t\t\tvar phys_bonus = global_bonus + (caster_stats.get_stat_value("physical_damage") - 1.0)
\t\t\tattack_component.damage_physical = (final_base * phys_ratio) * (1.0 + phys_bonus)
\t\t\t
\t\t\tvar fire_bonus = global_bonus + (caster_stats.get_stat_value("fire_damage") - 1.0)
\t\t\tattack_component.damage_fire = (final_base * fire_ratio) * (1.0 + fire_bonus)
\t\t\t
\t\t\tvar ice_bonus = global_bonus + (caster_stats.get_stat_value("ice_damage") - 1.0)
\t\t\tattack_component.damage_ice = (final_base * ice_ratio) * (1.0 + ice_bonus)
\t\t\t
\t\t\tvar lightning_bonus = global_bonus + (caster_stats.get_stat_value("lightning_damage") - 1.0)
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)'''

content = content.replace(old_block, new_block)

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch additive applique !")
