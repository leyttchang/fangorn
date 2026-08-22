# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_vars = '''@onready var scaling_component = 
@onready var attack_component = 
@onready var collision = /CollisionShape3D
@onready var decal = /Decal
@onready var ice_crash_effect = 

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(attack_component):
		attack_component.queue_free()'''

content = re.sub(r'@onready var scaling_component = \.*?func _ready\(\) -> void:\n\tpass', new_vars, content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write(content)
