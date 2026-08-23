import os

path = 'Y:/Fangorn/fangorn/scripts/globals/game_data.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_list = '''\t\t\tpreload("res://scripts/abilities/ice_nova/IceNova.tres"),
\t\t\tpreload("res://scripts/abilities/lightning_strike/LightningStrike.tres"),
\t\t\t
\t\t]'''
new_list = '''\t\t\tpreload("res://scripts/abilities/ice_nova/IceNova.tres"),
\t\t\tpreload("res://scripts/abilities/lightning_strike/LightningStrike.tres"),
\t\t\tpreload("res://scripts/abilities/thunder_slash/thunder_slash.tres"),
\t\t]'''

if 'thunder_slash.tres' not in content:
    content = content.replace(old_list, new_list)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        print("Spells patched!")
