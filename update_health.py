with open("Y:/Fangorn/fangorn/components/health_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

new_funcs = """
# --- FONCTIONS POUR LE BLOOD MAGIC (RENOUNCEMENT) ---
func pay_health_cost(amount: float) -> void:
	current_health -= amount
	current_health = max(current_health, 0.0)
	var max_hp = stats_component.get_stat_value("max_health")
	health_changed.emit(current_health, max_hp)

func heal(amount: float) -> void:
	var max_hp = stats_component.get_stat_value("max_health")
	current_health += amount
	current_health = min(current_health, max_hp)
	health_changed.emit(current_health, max_hp)
"""

content = content + new_funcs

with open("Y:/Fangorn/fangorn/components/health_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated health_component.gd")
