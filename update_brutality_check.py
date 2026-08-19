with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """func _handle_inputs() -> void:
	if not can_cast_spells:
		return
	for action in slots.keys():
		if Input.is_action_just_pressed(action):
			var ability: AbilityData = slots[action]
			if ability != null:
				if cooldown_timers.has(ability.ability_name):"""

new_logic = """func _handle_inputs() -> void:
	for action in slots.keys():
		if Input.is_action_just_pressed(action):
			var ability: AbilityData = slots[action]
			if ability != null:
				if not can_cast_spells and ability.category == AbilityData.AbilityCategory.MAGIC:
					# print(ability.ability_name, " est bloqué (Magie interdite) !")
					continue
					
				if cooldown_timers.has(ability.ability_name):"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated skill_bar_component.gd for Brutality check")
