import os

# 1. Patch AttackComponent
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@export var damage: float = 1', '''@export var base_damage: float = 1.0

# Les dgts finaux calculs (remplis par le SpellScalingComponent)
var damage_physical: float = 0.0
var damage_magic: float = 0.0
var damage_fire: float = 0.0
var damage_ice: float = 0.0
var damage_lightning: float = 0.0
''')

# Dans _ready, initialiser damage_physical
content = content.replace('func _ready() -> void:', '''func _ready() -> void:
\t# Par dfaut (sans SpellScalingComponent), 100% des dgts sont physiques
\tdamage_physical = base_damage
''')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Patch HitboxComponent
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('health_component.take_damage(attack.damage)', '''var total_damage = attack.damage_physical + attack.damage_magic + attack.damage_fire + attack.damage_ice + attack.damage_lightning
\t\thealth_component.take_damage(total_damage)''')

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 3. Patch SpellScalingComponent
new_spell_scaling = '''class_name SpellScalingComponent
extends Node

@export var attack_component: AttackComponent
@export var base_impact_radius: float = 4.0

@export_group("Weapon Scaling")
@export var use_weapon_damage: bool = false
@export var base_weapon_multiplier: float = 1.0

@export_group("Tags du Sort (Multiplicateurs Globaux)")
## Si coch, le sort bnficie de la stat magic_damage sur TOUS ses dgts
@export var is_spell: bool = false
## Si coch, le sort bnficie de la stat physical_damage sur TOUS ses dgts (Attack Damage)
@export var is_attack: bool = false
## Si coch, le sort bnficie de la stat aoe_damage sur TOUS ses dgts
@export var is_aoe: bool = false

@export_group("Base Damage Split (%)")
@export_range(0.0, 1.0) var phys_ratio: float = 1.0
@export_range(0.0, 1.0) var magic_ratio: float = 0.0
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
\t\tvar base_spell_damage = attack_component.base_damage
\t\tvar final_base = base_spell_damage
\t\t
\t\tif use_weapon_damage:
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
\t\tif caster_stats != null:
\t\t\t# 1. Calcul du multiplicateur global (Tags)
\t\t\tvar global_mult = 1.0
\t\t\tif is_spell: global_mult += caster_stats.get_stat_value("magic_damage")
\t\t\tif is_attack: global_mult += caster_stats.get_stat_value("physical_damage")
\t\t\tif is_aoe: global_mult += caster_stats.get_stat_value("aoe_damage")
\t\t\t
\t\t\t# 2. Rpartition et application des multiplicateurs lmentaires
\t\t\tattack_component.damage_physical = (final_base * phys_ratio) * (global_mult + caster_stats.get_stat_value("physical_damage"))
\t\t\tattack_component.damage_magic = (final_base * magic_ratio) * (global_mult + caster_stats.get_stat_value("magic_damage"))
\t\t\tattack_component.damage_fire = (final_base * fire_ratio) * (global_mult + caster_stats.get_stat_value("fire_damage"))
\t\t\tattack_component.damage_ice = (final_base * ice_ratio) * (global_mult + caster_stats.get_stat_value("ice_damage"))
\t\t\tattack_component.damage_lightning = (final_base * lightning_ratio) * (global_mult + caster_stats.get_stat_value("lightning_damage"))
\t\telse:
\t\t\t# Si pas de stats, on divise juste les dgts de base
\t\t\tattack_component.damage_physical = final_base * phys_ratio
\t\t\tattack_component.damage_magic = final_base * magic_ratio
\t\t\tattack_component.damage_fire = final_base * fire_ratio
\t\t\tattack_component.damage_ice = final_base * ice_ratio
\t\t\tattack_component.damage_lightning = final_base * lightning_ratio
\t\t
\t\t# 3. Scaling du Knockback
\t\tif caster_stats != null:
\t\t\tvar kb_mult = caster_stats.get_stat_value("knockback_power")
\t\t\tif kb_mult == 0.0: 
\t\t\t\tkb_mult = 1.0
\t\t\tattack_component.knockback_force *= kb_mult
\t
\t# 4. SCALING AOE
\tif caster_stats != null:
\t\tvar aoe_mult = caster_stats.get_stat_value("area_of_effect")
\t\tif aoe_mult == 0.0:
\t\t\taoe_mult = 1.0
\t\tfinal_aoe_multiplier = aoe_mult
\t\tfinal_impact_radius = base_impact_radius * aoe_mult
'''

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(new_spell_scaling)

print("Patch applique !")
