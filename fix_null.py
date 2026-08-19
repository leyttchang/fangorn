with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """				var force = tag_match_multiplier_per_tag_minor
				if n_skill.node_type == SkillNodeData.NodeType.NOTABLE:
					force = tag_match_multiplier_per_tag_notable
				elif n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					force = tag_match_multiplier_per_tag_keystone"""

new_logic = """				var force: float = 2.5
				if tag_match_multiplier_per_tag_minor != null: force = tag_match_multiplier_per_tag_minor
				if n_skill.node_type == SkillNodeData.NodeType.NOTABLE:
					force = 6.0
					if tag_match_multiplier_per_tag_notable != null: force = tag_match_multiplier_per_tag_notable
				elif n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					force = 8.0
					if tag_match_multiplier_per_tag_keystone != null: force = tag_match_multiplier_per_tag_keystone"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Applied hot-reload null fix")
