# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
# On rcupre directement les enfants grce  ton architecture
@onready var scaling_component = 
@onready var attack_component = 
@onready var collision = /CollisionShape3D
@onready var decal = /Decal
@onready var ice_crash_effect = 

func _ready() -> void:
	# 5. On dtruit SEULEMENT l'AttackComponent aprs 1.5 secondes (comme Ice Nova)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(attack_component):
		attack_component.queue_free()
'''

content = content.replace('''
# On r?cupre directement les enfants gr?ce  ton architecture
@onready var scaling_component = 
@onready var collision = /CollisionShape3D
@onready var decal = /Decal

func _ready() -> void:
	pass
''', replacement)

replacement2 = '''			
		# 3. SCALING DU VISUEL (Le Decal + Les Pics + La fume)
		var scale_factor = final_radius / 6.0 # 6.0 est le radius de base de ton sort
		if ice_crash_effect != null:
			# a va scale TOUT ce qu'il y a dans Ice_crash_effect (pics, fume, decal)
			ice_crash_effect.scale = Vector3(scale_factor, scale_factor, scale_factor)
'''

content = content.replace('''			
		# 3. SCALING DU VISUEL (Le Decal)
		if decal != null:
			decal.size = Vector3(final_radius * 2.0, decal.size.y, final_radius * 2.0)
''', replacement2)

with open('Y:/Fangorn/fangorn/scripts/abilities/Ice Crash/ice_crash.gd', 'w', encoding='utf-8') as f:
    f.write(content)
