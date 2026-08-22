# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace variables and ready
new_vars = '''@onready var scaling_component = 
@onready var collision = /CollisionShape3D
@onready var decal = /Decal
@onready var attack_component = 
@onready var ice_crash_effect = 

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(attack_component):
		attack_component.queue_free()'''

content = re.sub(r'@onready var scaling_component = \\n@onready var collision = \/CollisionShape3D\n@onready var decal = \/Decal\n\nfunc _ready\(\) -> void:\n\tpass', new_vars, content)

# Replace decal scaling
new_scale = '''		# 3. SCALING DU VISUEL (Le Decal + Les Pics + La fume)
		var scale_factor = final_radius / 6.0 # 6.0 est le radius de base
		if ice_crash_effect != null:
			ice_crash_effect.scale = Vector3(scale_factor, scale_factor, scale_factor)'''

content = re.sub(r'# 3\. SCALING DU VISUEL.*?decal\.size = Vector3\(final_radius \* 2\.0, decal\.size\.y, final_radius \* 2\.0\)', new_scale, content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write(content)
