with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/stone_statue_keystone.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("stats.add_modifier(\"armor\", 1, 100.0, \"stone_statue\")", "stats.add_modifier(\"armor\", 1, 1.0, \"stone_statue\")")

with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/Keystone/stone_statue_keystone.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed stone statue armor value")
