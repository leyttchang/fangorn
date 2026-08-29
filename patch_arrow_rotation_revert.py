import re

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''			if impact_normal.length_squared() > 0.001:
				var t = Transform3D()
				t.origin = global_position
				var up_dir = Vector3.UP
				if abs(impact_normal.dot(Vector3.UP)) > 0.99:
					up_dir = Vector3.RIGHT
				t = t.looking_at(global_position + impact_normal, up_dir)
				t = t.rotated_local(Vector3.RIGHT, -PI/2.0)
				blood.global_transform = t''',
'''			if impact_normal.length_squared() > 0.001:
				var up_dir = Vector3.UP
				if abs(impact_normal.dot(Vector3.UP)) > 0.99:
					up_dir = Vector3.RIGHT
				blood.look_at(global_position + impact_normal, up_dir)'''
)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
