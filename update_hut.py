with open("Y:/Fangorn/fangorn/components/health_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Add variable
var_insert = "var current_health: float\nvar _known_max_health: float # NOUVEAU : On mémorise l'ancienne limite\nvar has_cheat_death: bool = false # Pour le Hut Builder"
content = content.replace("var current_health: float\nvar _known_max_health: float # NOUVEAU : On mǸmorise l'ancienne limite", var_insert)

# Replace take_damage check
old_check = """	# 4. On applique les dégâts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	
	# On s'assure que la vie ne descend pas en dessous de zéro
	current_health = max(current_health, 0.0)"""

new_check = """	# 4. On applique les dégâts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	
	# --- MÉCANIQUE CHEAT DEATH (Hut Builder) ---
	if current_health <= 0 and has_cheat_death:
		has_cheat_death = false
		var max_hp_cheat = stats_component.get_stat_value("max_health")
		current_health = max_hp_cheat * 0.25
	
	# On s'assure que la vie ne descend pas en dessous de zéro
	current_health = max(current_health, 0.0)"""

# Handle encoding differences with "dégâts" and "zéro" from cat
content = content.replace("	# 4. On applique les d\u01f8g\u01fcts\n\tcurrent_health -= final_damage\n\tdamage_taken.emit(final_damage)\n\t\n\t# On s'assure que la vie ne descend pas en dessous de z\u01f8ro\n\tcurrent_health = max(current_health, 0.0)", new_check)

with open("Y:/Fangorn/fangorn/components/health_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated health_component.gd for Hut Builder")
