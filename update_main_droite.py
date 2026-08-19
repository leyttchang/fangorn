with open("Y:/Fangorn/fangorn/character/main_droite.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Add variable
if "var has_hit_in_combo_swing" not in content:
    content = content.replace("var combo_step: int = 1", "var combo_step: int = 1\nvar has_hit_in_combo_swing: bool = false")

# Add _on_weapon_hit
if "func _on_weapon_hit" not in content:
    content += """
func _on_weapon_hit(target: Node3D) -> void:
	if target.get_parent().is_in_group("Enemie"):
		if not has_hit_in_combo_swing:
			has_hit_in_combo_swing = true
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")
"""

# Modify enable_current_hitbox
old_enable = """func enable_current_hitbox():
	if is_instance_valid(current_weapon):
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")"""

new_enable = """func enable_current_hitbox():
	if is_instance_valid(current_weapon):
		var ac = current_weapon.attack_component
		if ac != null and not ac.attack_landed.is_connected(_on_weapon_hit):
			ac.attack_landed.connect(_on_weapon_hit)
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")"""
content = content.replace(old_enable, new_enable)

# Modify disable_current_hitbox
old_disable = """		current_weapon.attack_component.reset_hit_entities() 
		if is_instance_valid(shape): shape.set_deferred("disabled", true)"""

new_disable = """		current_weapon.attack_component.reset_hit_entities() 
		has_hit_in_combo_swing = false
		if is_instance_valid(shape): shape.set_deferred("disabled", true)"""
content = content.replace(old_disable, new_disable)

# Modify check_combo
old_combo = """			if is_instance_valid(current_weapon):
				current_weapon.attack_component.reset_hit_entities()
				current_weapon.update_damage_from_stats(player_stats, combo_step)"""

new_combo = """			if is_instance_valid(current_weapon):
				current_weapon.attack_component.reset_hit_entities()
				has_hit_in_combo_swing = false
				current_weapon.update_damage_from_stats(player_stats, combo_step)"""
content = content.replace(old_combo, new_combo)


with open("Y:/Fangorn/fangorn/character/main_droite.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated main_droite.gd")
