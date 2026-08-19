with open("Y:/Fangorn/fangorn/components/attack_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_chunk = """		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie"):
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")
				
		attack_landed.emit(area)"""

new_chunk = """		attack_landed.emit(area)"""

content = content.replace(old_chunk, new_chunk)

with open("Y:/Fangorn/fangorn/components/attack_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Cleaned attack_component.gd")
