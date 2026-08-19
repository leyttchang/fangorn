with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---
		var thematic_multiplier = 1.0
		if skill.node_type != SkillNodeData.NodeType.KEYSTONE:
			for n_skill in neighbor_skills:
				var shared_tags = skill.tags & n_skill.tags
				if shared_tags != 0:
					# Compter le nombre de tags en commun (bits à 1)
					var count = 0
					var temp = shared_tags
					while temp > 0:
						count += temp & 1
						temp = temp >> 1
					thematic_multiplier += 4.0 * count # +400% de poids par Tag en commun !
		weight *= thematic_multiplier
		# ----------------------------------------"""

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
				thematic_multiplier += 4.0 * count # +400% de poids par Tag en commun !
		weight *= thematic_multiplier
		# ----------------------------------------"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated thematic logic to include keystones")
