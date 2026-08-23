import os

path = 'Y:/Fangorn/fangorn/character/main_droite.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_func = '''func enable_current_hitbox():
\tif is_instance_valid(current_weapon):
\t\tvar ac = current_weapon.attack_component'''

new_func = '''func enable_current_hitbox():
\t# Si l'arme n'est pas encore liee, on le fait maintenant
\tif current_weapon == null and get_child_count() > 0:
\t\tcurrent_weapon = get_child(0)
\t\t
\tif is_instance_valid(current_weapon):
\t\t# On recalcule les degats systematiquement (comme ca, meme lance via un sort, ca tape juste !)
\t\tcurrent_weapon.update_damage_from_stats(player_stats, combo_step)
\t\t
\t\tvar ac = current_weapon.attack_component'''

content = content.replace(old_func, new_func)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
