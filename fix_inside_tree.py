with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_gen = """func generate_tree():
	var current_seed = tree_seed"""
new_gen = """func generate_tree():
	if not is_inside_tree():
		return
	var current_seed = tree_seed"""

content = content.replace(old_gen, new_gen)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added is_inside_tree check")
