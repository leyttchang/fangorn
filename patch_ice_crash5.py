# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
for i, line in enumerate(lines):
    if line.startswith('@onready var scaling_component ='):
        lines[i] = '''@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D
@onready var decal = $Ice_crash_effect/Decal
@onready var attack_component = $AttackComponent
@onready var ice_crash_effect = $Ice_crash_effect'''
    elif line.startswith('@onready var collision ='):
        lines[i] = ''
    elif line.startswith('@onready var decal ='):
        lines[i] = ''
    elif line.startswith('@onready var attack_component ='):
        lines[i] = ''
    elif line.startswith('@onready var ice_crash_effect ='):
        lines[i] = ''

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
