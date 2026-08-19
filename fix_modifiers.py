with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("for mod in skill.modifiers:", "for mod in skill.stats_bonuses:")
content = content.replace("for n_mod in n_skill.modifiers:", "for n_mod in n_skill.stats_bonuses:")

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated modifiers to stats_bonuses")
