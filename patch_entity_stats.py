import os

path = 'Y:/Fangorn/fangorn/scripts/stats/entity_stats.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_stats = '''@export var xp_reward: float = 10.0
@export var fire_resistance: float = 0.0
@export var ice_resistance: float = 0.0
@export var lightning_resistance: float = 0.0
'''
content = content.replace('@export var xp_reward: float = 10.0', new_stats)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
