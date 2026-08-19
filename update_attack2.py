with open("Y:/Fangorn/fangorn/components/attack_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Replace the previous update we did
old_chunk = """		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie"):
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")"""

new_chunk = """		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie") and not _is_spell_attack():
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")"""

content = content.replace(old_chunk, new_chunk)

# Add _is_spell_attack helper
if "_is_spell_attack" not in content:
    helper = """
func _is_spell_attack() -> bool:
	var p = get_parent()
	if p != null:
		for c in p.get_children():
			if c is SpellScalingComponent:
				return true
	return false
"""
    content += helper

with open("Y:/Fangorn/fangorn/components/attack_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated attack_component.gd for spell filtering")
