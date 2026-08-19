with open("Y:/Fangorn/fangorn/character/main_droite.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Replace the check
old_check = 'if target.get_parent().is_in_group("Enemie"):'
new_check = 'if target.get_parent().is_in_group("Enemie") or "Dummy" in target.get_parent().name:'

content = content.replace(old_check, new_check)

with open("Y:/Fangorn/fangorn/character/main_droite.gd", "w", encoding="utf-8") as f:
    f.write(content)
