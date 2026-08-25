import re

with open('Y:/Fangorn/fangorn/scripts/globals/game_data.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''\t\t\tpreload("res://scripts/abilities/thunder_aspect/thunder_aspect.tres"),
\t\t\tpreload("res://scripts/abilities/Warcry/warcry_ability.tres"),'''

content = content.replace(
    '\t\t\tpreload("res://scripts/abilities/thunder_aspect/thunder_aspect.tres"),',
    replacement
)

with open('Y:/Fangorn/fangorn/scripts/globals/game_data.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched game_data.gd for warcry")
