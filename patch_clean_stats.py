import os

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# On remplace l'ancien code par un nouveau bloc plus propre
old_block = '''\t\t\t# A. Recuperation des bonus globaux (Tags)
\t\t\t# Dans un systeme additif, on doit retirer la base (1.0) pour obtenir le BONUS brut !
\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tvar mag = caster_stats.get_stat_value("magic_damage")
\t\t\t\tif mag == 0.0: mag = 1.0
\t\t\t\tglobal_bonus += (mag - 1.0)
\t\t\tif is_aoe:
\t\t\t\tvar aoe = caster_stats.get_stat_value("area_of_effect")
\t\t\t\tif aoe == 0.0: aoe = 1.0
\t\t\t\tglobal_bonus += (aoe - 1.0)
\t\t\t
\t\t\t# B. Repartition sur les elements (On ajoute les bonus elementaires bruts, puis on remet la base 1.0)
\t\t\tvar val_physical_damage = caster_stats.get_stat_value("physical_damage")
\t\t\tif val_physical_damage == 0.0: val_physical_damage = 1.0
\t\t\tvar physical_bonus = global_bonus + (val_physical_damage - 1.0)
\t\t\tattack_component.damage_physical = (final_base * phys_ratio) * (1.0 + physical_bonus)
\t\t\t
\t\t\tvar val_fire_damage = caster_stats.get_stat_value("fire_damage")
\t\t\tif val_fire_damage == 0.0: val_fire_damage = 1.0
\t\t\tvar fire_bonus = global_bonus + (val_fire_damage - 1.0)
\t\t\tattack_component.damage_fire = (final_base * fire_ratio) * (1.0 + fire_bonus)
\t\t\t
\t\t\tvar val_ice_damage = caster_stats.get_stat_value("ice_damage")
\t\t\tif val_ice_damage == 0.0: val_ice_damage = 1.0
\t\t\tvar ice_bonus = global_bonus + (val_ice_damage - 1.0)
\t\t\tattack_component.damage_ice = (final_base * ice_ratio) * (1.0 + ice_bonus)
\t\t\t
\t\t\tvar val_lightning_damage = caster_stats.get_stat_value("lightning_damage")
\t\t\tif val_lightning_damage == 0.0: val_lightning_damage = 1.0
\t\t\tvar lightning_bonus = global_bonus + (val_lightning_damage - 1.0)
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)'''

new_block = '''\t\t\t# A. Recuperation des bonus globaux (Tags)
\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tglobal_bonus += _get_stat_bonus(caster_stats, "magic_damage")
\t\t\tif is_aoe:
\t\t\t\tglobal_bonus += _get_stat_bonus(caster_stats, "area_of_effect")
\t\t\t
\t\t\t# B. Repartition sur les elements (On ajoute les bonus elementaires bruts, puis on remet la base 1.0)
\t\t\tvar physical_bonus = global_bonus + _get_stat_bonus(caster_stats, "physical_damage")
\t\t\tattack_component.damage_physical = (final_base * phys_ratio) * (1.0 + physical_bonus)
\t\t\t
\t\t\tvar fire_bonus = global_bonus + _get_stat_bonus(caster_stats, "fire_damage")
\t\t\tattack_component.damage_fire = (final_base * fire_ratio) * (1.0 + fire_bonus)
\t\t\t
\t\t\tvar ice_bonus = global_bonus + _get_stat_bonus(caster_stats, "ice_damage")
\t\t\tattack_component.damage_ice = (final_base * ice_ratio) * (1.0 + ice_bonus)
\t\t\t
\t\t\tvar lightning_bonus = global_bonus + _get_stat_bonus(caster_stats, "lightning_damage")
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)'''

content = content.replace(old_block, new_block)

helper_func = '''\n\n# --- NOUVELLE FONCTION ---
# Permet de faire la difference entre "La stat n'existe pas" et "La stat a ete reduite a 0 par des malus"
func _get_stat_bonus(stats_node: Node, stat_name: String) -> float:
\tvar stat = stats_node.get_stat(stat_name)
\tif stat == null:
\t\t# La stat n'a pas encore ete codee dans StatsComponent -> Pas de bonus, pas de malus
\t\treturn 0.0
\t
\t# La stat existe ! On soustrait 1.0 pour recuperer UNIQUEMENT le bonus
\t# (Si des malus ont mis la valeur a 0.0, ca renverra bien 0.0 - 1.0 = -1.0)
\treturn stat.get_value() - 1.0
'''

if '_get_stat_bonus' not in content:
    content += helper_func

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch correctif applique !")
