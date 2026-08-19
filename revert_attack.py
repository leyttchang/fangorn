with open("Y:/Fangorn/fangorn/components/attack_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Restore the original hit code
new_chunk = """		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie") and not _is_spell_attack():
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")"""

old_chunk = """		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie"):
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")"""

content = content.replace(new_chunk, old_chunk)

# Remove the helper function completely
helper = """
func _is_spell_attack() -> bool:
	var p = get_parent()
	if p != null:
		for c in p.get_children():
			if c is SpellScalingComponent:
				return true
	return false
"""
content = content.replace(helper, "")

with open("Y:/Fangorn/fangorn/components/attack_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Reverted attack_component.gd")
