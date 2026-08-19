with open("Y:/Fangorn/fangorn/item/armes/weapon.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("attack_component.damage = (weapon_stats.base_damage + flat_bonus) * phys_multiplier * combo_multiplier", "attack_component.damage = (weapon_stats.base_damage + flat_bonus) * phys_multiplier * combo_multiplier\n\t\tprint(\"Weapon Damage Updated! phys_mult:\", phys_multiplier, \" -> final damage:\", attack_component.damage)")

with open("Y:/Fangorn/fangorn/item/armes/weapon.gd", "w", encoding="utf-8") as f:
    f.write(content)
