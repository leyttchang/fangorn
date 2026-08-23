# -*- coding: utf-8 -*-
import os

# --- PATCH HEALTH COMPONENT ---
health_path = 'Y:/Fangorn/fangorn/components/health_component.gd'
with open(health_path, 'r', encoding='utf-8') as f:
    h_content = f.read()

# On retire les exports d'armure
h_content = h_content.replace('@export var armor_curve: Curve', '')
h_content = h_content.replace('@export var max_expected_armor: float = 100.0', '')

old_health_logic = '''\t# 1. On demande l'armure actuelle au StatsComponent
\tvar armor = stats_component.get_stat_value("armor")
\tarmor = max(armor, 0.0) # On empASche d'avoir une armure nA©gative
\t
\t# 2. On calcule le pourcentage de rA©duction grA?ce A  la courbe
\tvar reduction_percent: float = 0.0
\t
\tif armor_curve != null:
\t\t# On calcule notre position sur l'axe horizontal du graphique (entre 0.0 et 1.0)
\t\tvar armor_position_on_x = armor / max_expected_armor
\t\t
\t\t# On s'assure de ne pas dA©passer le bout du graphique
\t\tarmor_position_on_x = min(armor_position_on_x, 1.0)
\t\t
\t\t# On demande A  la courbe de nous donner la valeur verticale (Y) correspondante
\t\treduction_percent = armor_curve.sample(armor_position_on_x)
\t
\t# 3. On calcule les dA©gA?ts finaux (DA©gA?ts purs multipliA©s par ce qu'il reste aprA¨s rA©duction)
\tvar final_damage = raw_damage * (1.0 - reduction_percent)
\t
\t# On garde ta sA©curitA© : une attaque rA©ussie fait toujours au moins 1 de dA©gA?t
\tfinal_damage = max(0.1, final_damage)'''

old_health_logic_clean = '''\t# 1. On demande l'armure actuelle au StatsComponent
\tvar armor = stats_component.get_stat_value("armor")
\tarmor = max(armor, 0.0) # On emp\u01e6che d'avoir une armure n\u01f8gative
\t
\t# 2. On calcule le pourcentage de r\u01f8duction gr\u01fdce \u00e0 la courbe
\tvar reduction_percent: float = 0.0
\t
\tif armor_curve != null:
\t\t# On calcule notre position sur l'axe horizontal du graphique (entre 0.0 et 1.0)
\t\tvar armor_position_on_x = armor / max_expected_armor
\t\t
\t\t# On s'assure de ne pas d\u01f8passer le bout du graphique
\t\tarmor_position_on_x = min(armor_position_on_x, 1.0)
\t\t
\t\t# On demande \u00e0 la courbe de nous donner la valeur verticale (Y) correspondante
\t\treduction_percent = armor_curve.sample(armor_position_on_x)
\t
\t# 3. On calcule les d\u01f8g\u01fdts finaux (D\u01f8g\u01fdts purs multipli\u01f8s par ce qu'il reste apr\u00e8s r\u01f8duction)
\tvar final_damage = raw_damage * (1.0 - reduction_percent)
\t
\t# On garde ta s\u01f8curit\u01f8 : une attaque r\u01f8ussie fait toujours au moins 1 de d\u01f8g\u01fdt
\tfinal_damage = max(0.1, final_damage)'''

new_health_logic = '''\t# L'armure et les resistances ont deja ete calculees dans HitboxComponent
\tvar final_damage = max(0.1, raw_damage)'''

h_content = h_content.replace(old_health_logic_clean, new_health_logic)

with open(health_path, 'w', encoding='utf-8') as f:
    f.write(h_content)


# --- PATCH HITBOX COMPONENT ---
hitbox_path = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(hitbox_path, 'r', encoding='utf-8') as f:
    hb_content = f.read()

hb_exports_old = '''@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU'''

hb_exports_new = '''@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU

@export_group("Mitigation (Armure & Resistances)")
@export var armor_curve: Curve
@export var max_expected_armor: float = 100.0'''

hb_content = hb_content.replace(hb_exports_old, hb_exports_new)

hb_logic_old = '''\t# 1. On applique les d\u01f8g\u01fdts
\tif health_component != null:
\t\tvar total_damage = attack.damage_physical + attack.damage_fire + attack.damage_ice + attack.damage_lightning
\t\thealth_component.take_damage(total_damage)'''

hb_logic_new = '''\t# 1. Calculs de reduction d'Armure et Resistances
\tif health_component != null:
\t\tvar dmg_phys = attack.damage_physical
\t\tvar dmg_fire = attack.damage_fire
\t\tvar dmg_ice = attack.damage_ice
\t\tvar dmg_lightning = attack.damage_lightning
\t\t
\t\tif health_component.stats_component != null:
\t\t\tvar stats = health_component.stats_component
\t\t\t
\t\t\t# --- ARMURE (Sur le Physique Uniquement) ---
\t\t\tvar armor = max(stats.get_stat_value("armor"), 0.0)
\t\t\tvar armor_reduction = 0.0
\t\t\tif armor_curve != null:
\t\t\t\tvar armor_x = min(armor / max_expected_armor, 1.0)
\t\t\t\tarmor_reduction = armor_curve.sample(armor_x)
\t\t\tdmg_phys *= (1.0 - armor_reduction)
\t\t\t
\t\t\t# --- RESISTANCES ELEMENTAIRES (Capees a 75%) ---
\t\t\tvar res_fire = min(stats.get_stat_value("fire_resistance"), 0.75)
\t\t\tvar res_ice = min(stats.get_stat_value("ice_resistance"), 0.75)
\t\t\tvar res_lightning = min(stats.get_stat_value("lightning_resistance"), 0.75)
\t\t\t
\t\t\tdmg_fire *= (1.0 - max(0.0, res_fire))
\t\t\tdmg_ice *= (1.0 - max(0.0, res_ice))
\t\t\tdmg_lightning *= (1.0 - max(0.0, res_lightning))
\t\t
\t\tvar total_damage = dmg_phys + dmg_fire + dmg_ice + dmg_lightning
\t\thealth_component.take_damage(total_damage)'''

hb_content = hb_content.replace(hb_logic_old, hb_logic_new)

with open(hitbox_path, 'w', encoding='utf-8') as f:
    f.write(hb_content)

print("Patch architecture reussi !")
