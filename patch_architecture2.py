# -*- coding: utf-8 -*-
import os, re

# --- PATCH HEALTH COMPONENT ---
health_path = 'Y:/Fangorn/fangorn/components/health_component.gd'
with open(health_path, 'r', encoding='utf-8') as f:
    h_content = f.read()

h_content = re.sub(r'@export var armor_curve: Curve\n', '', h_content)
h_content = re.sub(r'@export var max_expected_armor: float = 100\.0\n', '', h_content)

# We want to replace from # 1. On demande to inal_damage = max(0.1, final_damage)
pattern = re.compile(r'\t# 1\. On demande l\'armure actuelle.*?final_damage = max\(0\.1, final_damage\)', re.DOTALL)
new_health = '\t# Armure et resistances calculees dans HitboxComponent\n\tvar final_damage = max(0.1, raw_damage)'
h_content = pattern.sub(new_health, h_content)

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

hb_logic_pattern = re.compile(r'\t# 1\. On applique les d.*?health_component\.take_damage\(total_damage\)', re.DOTALL)

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

hb_content = hb_logic_pattern.sub(hb_logic_new, hb_content)

with open(hitbox_path, 'w', encoding='utf-8') as f:
    f.write(hb_content)

print("Patch architecture v2 reussi !")
