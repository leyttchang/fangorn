with open("Y:/Fangorn/fangorn/components/health_component.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip().startswith("var _known_max_health"):
        new_lines.append(line)
        new_lines.append("var has_cheat_death: bool = false\n")
        continue
    
    if line.strip() == "current_health = max(current_health, 0.0)":
        new_lines.append("\t# --- MÉCANIQUE CHEAT DEATH (Hut Builder) ---\n")
        new_lines.append("\tif current_health <= 0 and has_cheat_death:\n")
        new_lines.append("\t\thas_cheat_death = false\n")
        new_lines.append("\t\tvar max_hp_cheat = stats_component.get_stat_value(\"max_health\")\n")
        new_lines.append("\t\tcurrent_health = max_hp_cheat * 0.25\n")
        new_lines.append("\n")
        new_lines.append(line)
        continue
        
    new_lines.append(line)

with open("Y:/Fangorn/fangorn/components/health_component.gd", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
print("Updated health_component.gd via lines")
