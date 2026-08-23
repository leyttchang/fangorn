# -*- coding: utf-8 -*-
import os, re

# --- PATCH ATTACK COMPONENT ---
path_att = 'Y:/Fangorn/fangorn/components/attack_component.gd'
with open(path_att, 'r', encoding='utf-8') as f:
    content_att = f.read()

new_exports = '''@export var is_projectile: bool = false
@export var destroy_on_environment: bool = true

@export_group("Status Effects")
@export var status_effects_to_apply: Array[StatusEffectApplication] = []'''

content_att = content_att.replace('@export var is_projectile: bool = false\n@export var destroy_on_environment: bool = true', new_exports)

with open(path_att, 'w', encoding='utf-8') as f:
    f.write(content_att)


# --- PATCH HITBOX COMPONENT ---
path_hit = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(path_hit, 'r', encoding='utf-8') as f:
    content_hit = f.read()

new_hit = '''\t# 1. Calculs de reduction d'Armure et Resistances
\tif health_component != null:
\t\tvar dmg_phys = attack.damage_physical
\t\tvar dmg_fire = attack.damage_fire
\t\tvar dmg_ice = attack.damage_ice
\t\tvar dmg_lightning = attack.damage_lightning
\t\t
\t\tvar damage_taken_mult = 1.0
\t\t
\t\tif health_component.stats_component != null:
\t\t\tvar stats = health_component.stats_component
\t\t\t
\t\t\t# --- MULTIPLICATEUR DE DEGATS RECUS (Ex: Shock) ---
\t\t\t# Si la stat n'existe pas, elle renverra 0.0, donc on l'ajoute a 1.0
\t\t\tdamage_taken_mult = max(0.0, 1.0 + stats.get_stat_value("damage_taken_multiplier"))
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
\t\tvar total_damage = (dmg_phys + dmg_fire + dmg_ice + dmg_lightning) * damage_taken_mult
\t\thealth_component.take_damage(total_damage)

\t# 2. Application des Status Effects
\tif "status_effects_to_apply" in attack and attack.status_effects_to_apply.size() > 0:
\t\tvar status_comp = get_parent().get_node_or_null("StatusEffectComponent")
\t\t# Tenter avec l'orthographe actuelle
\t\tif status_comp == null: status_comp = get_parent().get_node_or_null("StatusEffectComponant")
\t\tif status_comp != null and status_comp.has_method("apply_effect"):
\t\t\tfor app in attack.status_effects_to_apply:
\t\t\t\tif randf() <= app.apply_chance:
\t\t\t\t\tstatus_comp.apply_effect(app.effect, app.duration)
'''

content_hit = re.sub(r'\t# 1\. Calculs de reduction d\'Armure.*?health_component\.take_damage\(total_damage\)', new_hit, content_hit, flags=re.DOTALL)

with open(path_hit, 'w', encoding='utf-8') as f:
    f.write(content_hit)

print("Patch hitbox et attack reussi !")
