with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_vars = """@export_range(0.0, 10.0) var tag_match_multiplier_per_tag: float = 4.0"""
new_vars = """@export_range(0.0, 10.0) var tag_match_multiplier_per_tag_minor: float = 2.5
@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_notable: float = 6.0
@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_keystone: float = 8.0"""
content = content.replace(old_vars, new_vars)

old_logic = """		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---
		var thematic_multiplier = 1.0
		for n_skill in neighbor_skills:
			var shared_tags = skill.tags & n_skill.tags
			if shared_tags != 0:
				# Compter le nombre de tags en commun (bits à 1)
				var count = 0
				var temp = shared_tags
				while temp > 0:
					count += temp & 1
					temp = temp >> 1
				thematic_multiplier += tag_match_multiplier_per_tag * count
		weight *= thematic_multiplier"""

new_logic = """		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---
		var thematic_multiplier = 1.0
		for n_skill in neighbor_skills:
			var shared_tags = skill.tags & n_skill.tags
			if shared_tags != 0:
				# Compter le nombre de tags en commun (bits à 1)
				var count = 0
				var temp = shared_tags
				while temp > 0:
					count += temp & 1
					temp = temp >> 1
					
				var force = tag_match_multiplier_per_tag_minor
				if n_skill.node_type == SkillNodeData.NodeType.NOTABLE:
					force = tag_match_multiplier_per_tag_notable
				elif n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					force = tag_match_multiplier_per_tag_keystone
					
				thematic_multiplier += force * count
		weight *= thematic_multiplier"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator with different thematic forces")
