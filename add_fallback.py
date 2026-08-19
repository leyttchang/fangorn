with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_init = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], dead_end_length: int = 0) -> SkillNodeData:
	var best_candidates = []
	var total_weight = 0.0"""
new_init = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], dead_end_length: int = 0) -> SkillNodeData:
	var best_candidates = []
	var total_weight = 0.0
	var fallback_candidates = []
	var fallback_total_weight = 0.0"""
content = content.replace(old_init, new_init)

old_logic = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if is_leaf and dead_end_length > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				weight *= (1.0 + float(dead_end_length) * dead_end_keystone_multiplier_per_depth)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and dead_end_length > dead_end_minor_cutoff_depth:
				weight = 0.0
		# -------------------------------------
		
		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---
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
		weight *= thematic_multiplier
		# ----------------------------------------
		
		if weight > 0:
			best_candidates.append({"skill": skill, "weight": weight})
			total_weight += weight
			
	if best_candidates.is_empty():
		return null"""
new_logic = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		var is_banned_minor = false
		if is_leaf and dead_end_length > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				weight *= (1.0 + float(dead_end_length) * dead_end_keystone_multiplier_per_depth)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and dead_end_length > dead_end_minor_cutoff_depth:
				is_banned_minor = true
		# -------------------------------------
		
		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---
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
		weight *= thematic_multiplier
		# ----------------------------------------
		
		if weight > 0:
			if is_banned_minor:
				fallback_candidates.append({"skill": skill, "weight": weight})
				fallback_total_weight += weight
			else:
				best_candidates.append({"skill": skill, "weight": weight})
				total_weight += weight
			
	if best_candidates.is_empty():
		if not fallback_candidates.is_empty():
			# Sécurité : on utilise les mineurs bannis si on a rien d'autre
			best_candidates = fallback_candidates
			total_weight = fallback_total_weight
		else:
			return null"""
content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added fallback logic")
