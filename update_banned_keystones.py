with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """		var type_multiplier = 1.0"""
new_logic = """		# --- INTERDIRE LES KEYSTONES COTE A COTE ---
		var is_banned_keystone = false
		if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
			for n_skill in neighbor_skills:
				if n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					is_banned_keystone = true
					break
		# -------------------------------------------
		
		var type_multiplier = 1.0"""

content = content.replace(old_logic, new_logic)

old_banned = """		if weight > 0:
			if is_banned_minor:"""
new_banned = """		if weight > 0:
			if is_banned_minor or is_banned_keystone:"""

content = content.replace(old_banned, new_banned)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator with banned keystone logic")
