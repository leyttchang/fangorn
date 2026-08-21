# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
old_func_pattern = r'func _on_attack_landed.*?queue_free\(\)'
new_func = '''func _on_attack_landed(target: Node) -> void:
	if _has_impacted:
		return
	_has_impacted = true

	var is_character = false
	if target is HitboxComponent:
		if target.get_parent() is CharacterBody3D:
			is_character = true
	elif target is CharacterBody3D:
		is_character = true

	if is_character:
		# Si on touche un personnage (joueur ou autre), la flche se dtruit immdiatement
		if is_inside_tree() and multiplayer.is_server():
			queue_free()
		return

	# 1. Stopper la physique et dsactiver la collision principale du projectile (si on touche le dcor)
	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_physics_process(false)
	
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)

	# 2. Dsactiver la Hurtbox / AttackComponent pour viter d'infliger des dgts  nouveau
	if attack_component != null:
		attack_component.set_deferred("monitoring", false)
		attack_component.set_deferred("monitorable", false)
		var attack_col = attack_component.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if attack_col != null:
			attack_col.set_deferred("disabled", true)

	# 3. Faire disparatre la flche aprs 10 secondes (si elle est dans un mur)
	await get_tree().create_timer(stick_duration).timeout
	if is_instance_valid(self):
		if is_inside_tree() and multiplayer.is_server():
			queue_free()'''

content = re.sub(old_func_pattern, new_func, content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Arrow destruction on hit patched")
