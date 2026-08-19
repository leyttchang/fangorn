with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Replace export
old_export = """@export_group("Types & Thèmes")
@export_range(1.0, 10.0) var type_match_multiplier: float = 3.0
@export_range(0.0, 10.0) var tag_match_multiplier_per_tag: float = 4.0"""

new_export = """@export_group("Types & Thèmes")
@export_range(1.0, 10.0) var minor_match_multiplier: float = 3.0
@export_range(1.0, 10.0) var notable_match_multiplier: float = 3.0
@export_range(1.0, 10.0) var keystone_match_multiplier: float = 3.0
@export_range(0.0, 10.0) var tag_match_multiplier_per_tag: float = 4.0"""

content = content.replace(old_export, new_export)

# 2. Update logic in _draft_skill
old_logic = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = type_match_multiplier"""

new_logic = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			if desired_type == SkillNodeData.NodeType.MINOR:
				type_multiplier = minor_match_multiplier
			elif desired_type == SkillNodeData.NodeType.NOTABLE:
				type_multiplier = notable_match_multiplier
			elif desired_type == SkillNodeData.NodeType.KEYSTONE:
				type_multiplier = keystone_match_multiplier"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Decomposed type multipliers")
