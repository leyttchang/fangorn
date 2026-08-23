import os

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Nettoyer les variables exportes
content = content.replace('@export var is_attack: bool = false\\n', '')
content = content.replace('## Si coch, le sort bnficie de la stat physical_damage sur TOUS ses dgts (Attack Damage)\\n', '')
content = content.replace('@export_range(0.0, 1.0) var magic_ratio: float = 0.0\\n', '')

# 2. Nettoyer les calculs
content = content.replace('if is_attack: global_mult += caster_stats.get_stat_value("physical_damage")\\n', '')
content = content.replace('attack_component.damage_magic = (final_base * magic_ratio) * (global_mult + caster_stats.get_stat_value("magic_damage"))\\n', '')
content = content.replace('attack_component.damage_magic = final_base * magic_ratio\\n', '')

with open('Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 3. Nettoyer AttackComponent
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content_atk = f.read()
content_atk = content_atk.replace('var damage_magic: float = 0.0\\n', '')
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content_atk)

# 4. Nettoyer HitboxComponent
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content_hit = f.read()
content_hit = content_hit.replace('attack.damage_magic + ', '')
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content_hit)

print("Patch de nettoyage applique !")
