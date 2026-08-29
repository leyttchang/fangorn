import re

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''	if impact_normal.length_squared() > 0.001:
		var up_dir = Vector3.UP
		if abs(impact_normal.dot(Vector3.UP)) > 0.99:
			up_dir = Vector3.RIGHT
		blood.look_at(impact_point + impact_normal, up_dir)''',
'''	if impact_normal.length_squared() > 0.001:
		# Pour que le sang gicle VERS l'exterieur (le long de la normale), 
		# il faut aligner l'axe Y (direction des particules) avec la normale.
		var t = Transform3D()
		t.origin = impact_point
		var up_dir = Vector3.UP
		if abs(impact_normal.dot(Vector3.UP)) > 0.99:
			up_dir = Vector3.RIGHT
		t = t.looking_at(impact_point + impact_normal, up_dir)
		# looking_at aligne -Z sur la normale. On tourne de -90 degres sur X pour aligner Y sur la normale
		t = t.rotated_local(Vector3.RIGHT, -PI/2.0)
		blood.global_transform = t'''
)

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
