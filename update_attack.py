with open("Y:/Fangorn/fangorn/components/attack_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_hit = """		if area.has_method("receive_hit"):
			area.receive_hit(self)
		attack_landed.emit(area)"""

new_hit = """		if area.has_method("receive_hit"):
			area.receive_hit(self)
			
		# NOUVEAU : Si la cible est un ennemi, on prévient le joueur pour les combos
		if area.get_parent().is_in_group("Enemie"):
			var player = get_tree().get_first_node_in_group("Player")
			if player != null and player.has_signal("player_hit_enemy"):
				player.emit_signal("player_hit_enemy")
				
		attack_landed.emit(area)"""

if "player_hit_enemy" not in content:
    content = content.replace(old_hit, new_hit)

with open("Y:/Fangorn/fangorn/components/attack_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated attack_component.gd")
