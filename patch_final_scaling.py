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
\t\t\t\tflat_phys_stat = caster_stats.get_stat_value("flat_physical_damage")
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
\t\t\tvar kb_mult = caster_stats.get_stat_value("knockback_power")
\t\t\tif kb_mult == 0.0: 
\t\t\t\tkb_mult = 1.0
\t\t\tattack_component.knockback_force *= kb_mult
\t
\t# ====================================================
\t\t# 4. SCALING AOE (Taille visuelle/hitbox)
\t# ====================================================
\tif caster_stats != null:
\t\tvar aoe_mult = caster_stats.get_stat_value("area_of_effect")
\t\tif aoe_mult == 0.0:
\t\t\taoe_mult = 1.0
\t\tfinal_aoe_multiplier = aoe_mult
\t\tfinal_impact_radius = base_impact_radius * aoe_mult
'''

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Patch applique !")
