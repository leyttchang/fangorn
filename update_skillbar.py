with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("var current_state: State = State.IDLE", "var current_state: State = State.IDLE\nvar can_cast_spells: bool = true")
content = content.replace("func _handle_inputs() -> void:\n\tfor action in slots.keys():", "func _handle_inputs() -> void:\n\tif not can_cast_spells:\n\t\treturn\n\tfor action in slots.keys():")

with open("Y:/Fangorn/fangorn/components/skill_bar_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated skill_bar_component.gd")
