with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Compute dead_end_dist right before BFS loop
old_bfs_init = """	# 3. NOUVEAU: Parcourir le graphe depuis le centre (BFS) pour propager les thèmes
	var queue = [0]"""

new_bfs_init = """	# 2.5. Pré-calculer la profondeur des impasses (dead_end_dist)
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
				dead_end_dist[chain[j]] = j + 1

	# 3. NOUVEAU: Parcourir le graphe depuis le centre (BFS) pour propager les thèmes
	var queue = [0]"""

content = content.replace(old_bfs_init, new_bfs_init)

# 2. Pass dead_end_dist to _draft_skill
old_draft_1 = """				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills)
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)"""

new_draft_1 = """				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, dead_end_dist[curr])"""

content = content.replace(old_draft_1, new_draft_1)

# 3. Update _draft_skill definition
old_draft_def = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = []) -> SkillNodeData:"""
new_draft_def = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], current_dead_end_dist: int = 0) -> SkillNodeData:"""

content = content.replace(old_draft_def, new_draft_def)

# 4. Inject dead end logic inside _draft_skill
old_type_mult = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = 3.0 # On favorise le type idéal pour cet emplacement, mais sans excès
			
		weight *= type_multiplier
		
		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---"""

new_type_mult = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = 3.0 # On favorise le type idéal pour cet emplacement, mais sans excès
			
		weight *= type_multiplier
		
		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if current_dead_end_dist > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				# Plus l'impasse est longue, plus la keystone est probable
				weight *= (1.0 + float(current_dead_end_dist) * 2.5)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and current_dead_end_dist > 2:
				# Au delà de 2 de longueur d'impasse, les mineurs tombent à 0
				weight = 0.0
		# -------------------------------------
		
		# --- MULTIPLICATEUR THEMATIQUE (TAGS) ---"""

content = content.replace(old_type_mult, new_type_mult)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added dead end logic")
