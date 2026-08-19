with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update precalculation
old_precalc = """	# 2.5. Pré-calculer la profondeur des impasses (dead_end_dist)
	var dead_end_dist = {}
	for i in range(points.size()):
		dead_end_dist[i] = 0
		
	for i in range(points.size()):
		if _get_connections_count(i) == 1 and i != 0:
			var chain = []
			var c = i
			var p = -1
			while true:
				chain.append(c)
				var neighbors = adjacency_list[c]
				var next_node = -1
				for n in neighbors:
					if n != p:
						next_node = n
						break
				if next_node == -1 or _get_connections_count(next_node) != 2:
					break
				p = c
				c = next_node
				
			chain.reverse()
			for j in range(chain.size()):
				dead_end_dist[chain[j]] = j + 1"""

new_precalc = """	# 2.5. Pré-calculer la longueur des impasses (pour les feuilles uniquement)
	var leaf_dead_end_length = {}
	for i in range(points.size()):
		leaf_dead_end_length[i] = 0
		
	for i in range(points.size()):
		if _get_connections_count(i) == 1 and i != 0:
			var chain_length = 1
			var c = i
			var p = -1
			while true:
				var neighbors = adjacency_list[c]
				var next_node = -1
				for n in neighbors:
					if n != p:
						next_node = n
						break
				if next_node == -1 or _get_connections_count(next_node) != 2:
					break
				p = c
				c = next_node
				chain_length += 1
				
			leaf_dead_end_length[i] = chain_length"""

content = content.replace(old_precalc, new_precalc)

# 2. Update calls to _draft_skill
old_draft_1 = """				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])"""

new_draft_1 = """				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])"""

content = content.replace(old_draft_1, new_draft_1)

# 3. Update definition
old_def = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], current_dead_end_dist: int = 0) -> SkillNodeData:"""
new_def = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], dead_end_length: int = 0) -> SkillNodeData:"""

content = content.replace(old_def, new_def)

# 4. Update logic
old_logic = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if current_dead_end_dist > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				weight *= (1.0 + float(current_dead_end_dist) * dead_end_keystone_multiplier_per_depth)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and current_dead_end_dist > dead_end_minor_cutoff_depth:
				weight = 0.0"""
new_logic = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if is_leaf and dead_end_length > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				weight *= (1.0 + float(dead_end_length) * dead_end_keystone_multiplier_per_depth)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and dead_end_length > dead_end_minor_cutoff_depth:
				weight = 0.0"""
content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed dead end logic")
