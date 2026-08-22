# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
for i, line in enumerate(lines):
    if line.startswith('@onready var scaling_component'):
        lines[i] = '''@onready var scaling_component = 
@onready var collision = /CollisionShape3D
@onready var decal = /Decal
@onready var attack_component = 
@onready var ice_crash_effect = '''
    elif line.startswith('@onready var collision ='):
        lines[i] = ''
    elif line.startswith('@onready var decal ='):
        lines[i] = ''
    elif line.startswith('func _ready() -> void:'):
        lines[i] = '''func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(attack_component):
		attack_component.queue_free()'''
    elif line.strip() == 'pass' and lines[i-1].startswith('func _ready() -> void:'):
        lines[i] = ''

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
