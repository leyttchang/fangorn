import os

with open('Y:/Fangorn/fangorn/item/armes/weapon.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('attack_component.damage = weapon_stats.base_damage', '''attack_component.base_damage = weapon_stats.base_damage
\t\tattack_component.damage_physical = weapon_stats.base_damage''')
content = content.replace('attack_component.damage = (weapon_stats.base_damage + flat_bonus) * phys_multiplier * combo_multiplier', 'attack_component.damage_physical = (weapon_stats.base_damage + flat_bonus) * phys_multiplier * combo_multiplier')
content = content.replace('attack_component.damage)', 'attack_component.damage_physical)')

with open('Y:/Fangorn/fangorn/item/armes/weapon.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Weapon.gd patch applique !")
