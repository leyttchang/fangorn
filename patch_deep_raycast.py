import re

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''						hit_target = target
						impact_point = raycast.get_collision_point()
						impact_normal = raycast.get_collision_normal()
						
						# --- NOUVEAU : DEEP PENETRATION (Pour coller au Mesh/RigidBody) ---
						var ray_start = raycast.global_position
						var ray_end = raycast.to_global(raycast.target_position)
						var ray_dir = (ray_end - ray_start).normalized()
						
						var space_state = get_world_3d().direct_space_state
						var query = PhysicsRayQueryParameters3D.create(
							impact_point + ray_dir * 0.01, # On decale pour traverser la hitbox
							impact_point + ray_dir * 2.0   # On cherche plus profond a l'interieur
						)
						query.collision_mask = 0xFFFFFFFF # Scan toutes les couches pour trouver le vrai corps
						query.exclude = [collider.get_rid()]
						
						var deep_hit = space_state.intersect_ray(query)
						if deep_hit and deep_hit.collider != null:
							# Si le corps interne appartient bien a ce meme monstre
							if deep_hit.collider == target.owner or deep_hit.collider.owner == target.owner or deep_hit.collider == target.get_parent() or deep_hit.collider.get_parent() == target.owner:
								impact_point = deep_hit.position
								impact_normal = deep_hit.normal
						# -----------------------------------------------------------------
						break'''

content = content.replace(
'''						hit_target = target
						impact_point = raycast.get_collision_point()
						impact_normal = raycast.get_collision_normal()
						break''',
replacement
)

with open('Y:/Fangorn/fangorn/components/weapon_impact_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
