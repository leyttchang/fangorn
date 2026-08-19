with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/overwhelming_combo_keystone.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("hit_timestamps.append(Time.get_ticks_msec())", "hit_timestamps.append(Time.get_ticks_msec())\n\tprint(\"Overwhelming Combo: Hit Registered! Total hits: \", hit_timestamps.size())")

content = content.replace("stats.add_modifier(\"physical_damage\", 1, bonus, \"overwhelming_combo\")", "stats.add_modifier(\"physical_damage\", 1, bonus, \"overwhelming_combo\")\n\t\tprint(\"Overwhelming Combo: Buff Applied: +\", bonus*100, \"%\")")
content = content.replace("stats.remove_modifier_by_source(\"overwhelming_combo\")", "stats.remove_modifier_by_source(\"overwhelming_combo\")\n\tprint(\"Overwhelming Combo: Buff Removed\")")


with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/overwhelming_combo_keystone.gd", "w", encoding="utf-8") as f:
    f.write(content)

with open("Y:/Fangorn/fangorn/character/main_droite.gd", "r", encoding="utf-8") as f:
    main_content = f.read()
    
main_content = main_content.replace("if target.get_parent().is_in_group(\"Enemie\"):", "if target.get_parent().is_in_group(\"Enemie\"):\n\t\tprint(\"Main_droite: Hit enemy!\")")
main_content = main_content.replace("has_hit_in_combo_swing = true", "has_hit_in_combo_swing = true\n\t\t\tprint(\"Main_droite: Emitting player_hit_enemy signal!\")")

with open("Y:/Fangorn/fangorn/character/main_droite.gd", "w", encoding="utf-8") as f:
    f.write(main_content)
