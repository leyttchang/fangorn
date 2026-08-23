# -*- coding: utf-8 -*-
import os

new_code = '''class_name SpellScalingComponent
extends Node

@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0

@export_group("Type de Competence")
enum SkillType { SPELL, ATTACK }
@export var skill_type: SkillType = SkillType.SPELL

@export_group("Tags Globaux")
## Si coche, le sort beneficie de la stat aoe_damage (en plus de magic_damage si SPELL)
@export var is_aoe: bool = false

@export_group("Weapon Scaling (Si ATTACK)")
## Utilise si le sort n'a pas d'AbilityData (1.0 = 100% des degats de l'arme)
@export var base_weapon_multiplier: float = 1.0

@export_group("Base Damage Split (%)")
@export_range(0.0, 1.0) var phys_ratio: float = 1.0
@export_range(0.0, 1.0) var fire_ratio: float = 0.0
@export_range(0.0, 1.0) var ice_ratio: float = 0.0
@export_range(0.0, 1.0) var lightning_ratio: float = 0.0

var final_impact_radius: float = 4.0 
var final_aoe_multiplier: float = 1.0

func on_execute(caster: Node3D, target_data: Dictionary) -> void:
\tvar ability_data = target_data.get("ability_data") as AbilityData
\tvar caster_stats = caster.find_child("StatsComponent", true, false)
\tvar equipment = caster.find_child("EquipmentComponent", true, false)
\t
\tif attack_component != null:
\t\tvar final_base = attack_component.base_damage
\t\t
\t\t# ====================================================
\t\t# 1. GESTION DE L'ARME (Si c'est une Attaque)
\t\t# ====================================================
\t\tif skill_type == SkillType.ATTACK:
\t\t\tvar weapon_damage = 0.0
\t\t\tif equipment != null and equipment.equipped_items.has("main_hand"):
\t\t\t\tvar weapon = equipment.equipped_items["main_hand"]
\t\t\t\tif weapon != null and "base_damage" in weapon: 
\t\t\t\t\tweapon_damage = weapon.base_damage
\t\t\t
\t\t\tvar flat_phys_stat = 0.0
\t\t\tif caster_stats != null:
\t\t\t\tvar stat = caster_stats.get_stat("flat_physical_damage")
\t\t\t\tif stat != null: flat_phys_stat = stat.get_value()
\t\t\t\t
\t\t\tvar mult = base_weapon_multiplier
\t\t\tif ability_data != null:
\t\t\t\tmult = ability_data.weapon_damage_multiplier
\t\t\t\t
\t\t\tfinal_base += (weapon_damage + flat_phys_stat) * mult
\t\t\t
\t\t# ====================================================
\t\t# 2. CALCUL DES DEGATS (Systeme Additif)
\t\t# ====================================================
\t\tif caster_stats != null:
\t\t\t# A. Recuperation des bonus globaux (Tags)
\t\t\tvar global_bonus = 0.0
\t\t\tif skill_type == SkillType.SPELL:
\t\t\t\tglobal_bonus += _get_stat_bonus(caster_stats, "magic_damage")
\t\t\tif is_aoe:
\t\t\t\tglobal_bonus += _get_stat_bonus(caster_stats, "aoe_damage")
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
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (1.0 + lightning_bonus)
\t\telse:
\t\t\t# Sans stats, on divise juste la base
\t\t\tattack_component.damage_physical = final_base * phys_ratio
\t\t\tattack_component.damage_fire = final_base * fire_ratio
\t\t\tattack_component.damage_ice = final_base * ice_ratio
\t\t\tattack_component.damage_lightning = final_base * lightning_ratio
\t\t
\t\t# ====================================================
\t\t# 3. SCALING DU KNOCKBACK
\t\t# ====================================================
\t\tif caster_stats != null:
\t\t\tvar kb_stat = caster_stats.get_stat("knockback_power")
\t\t\tvar kb_mult = 1.0
\t\t\tif kb_stat != null:
\t\t\t\tkb_mult = kb_stat.get_value()
\t\t\tif kb_mult == 0.0: 
\t\t\t\tkb_mult = 1.0
\t\t\tattack_component.knockback_force *= kb_mult
\t
\t# ====================================================
\t# 4. SCALING AOE (Taille visuelle/hitbox)
\t# ====================================================
\tif caster_stats != null:
\t\tvar aoe_stat = caster_stats.get_stat("area_of_effect")
\t\tvar aoe_mult = 1.0
\t\tif aoe_stat != null:
\t\t\taoe_mult = aoe_stat.get_value()
\t\tif aoe_mult == 0.0:
\t\t\taoe_mult = 1.0
\t\tfinal_aoe_multiplier = aoe_mult
\t\tfinal_impact_radius = base_impact_radius * aoe_mult


# --- NOUVELLE FONCTION ---
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

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Patch propre applique !")
