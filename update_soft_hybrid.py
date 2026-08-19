with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update _get_zone and add _get_hybrid_zone
old_get_zone = """func _get_zone(pos: Vector2) -> int:
	var angle = pos.angle() 
	var hybrid_rad = deg_to_rad(hybrid_zone_width_degrees) / 2.0
	
	var bound_mage_barb = -PI/2.0
	var bound_duel_mage = PI/6.0
	var bound_barb_duel = 5.0*PI/6.0
	
	if abs(angle - bound_mage_barb) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_BARB_MAGE
	if abs(angle - bound_duel_mage) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_MAGE_DUEL
	if abs(angle - bound_barb_duel) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_DUEL_BARB
		
	if angle >= bound_mage_barb and angle < bound_duel_mage:
		return SkillNodeData.Zone.MAGE
	if angle >= bound_duel_mage and angle < bound_barb_duel:
		return SkillNodeData.Zone.DUELIST
	return SkillNodeData.Zone.BARBARIAN"""

new_get_zone = """func _get_zone(pos: Vector2) -> int:
	var angle = pos.angle() 
	var bound_mage_barb = -PI/2.0
	var bound_duel_mage = PI/6.0
	var bound_barb_duel = 5.0*PI/6.0
	
	if angle >= bound_mage_barb and angle < bound_duel_mage:
		return SkillNodeData.Zone.MAGE
	if angle >= bound_duel_mage and angle < bound_barb_duel:
		return SkillNodeData.Zone.DUELIST
	return SkillNodeData.Zone.BARBARIAN

func _get_hybrid_zone(pos: Vector2) -> int:
	var angle = pos.angle()
	var hybrid_rad = deg_to_rad(hybrid_zone_width_degrees) / 2.0
	
	var bound_mage_barb = -PI/2.0
	var bound_duel_mage = PI/6.0
	var bound_barb_duel = 5.0*PI/6.0
	
	if abs(angle - bound_mage_barb) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_BARB_MAGE
	if abs(angle - bound_duel_mage) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_MAGE_DUEL
	if abs(angle - bound_barb_duel) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_DUEL_BARB
	# Cas spécial pour la frontière Barb/Duelist qui pourrait déborder sur PI / -PI
	if abs(angle - (bound_barb_duel - TAU)) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_DUEL_BARB
		
	return SkillNodeData.Zone.ANY"""

content = content.replace(old_get_zone, new_get_zone)

# 2. Update BFS loop calling _draft_skill
old_draft_call = """		var zone = _get_zone(pt)
		var connections = _get_connections_count(curr)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (curr == 1 or curr == 2 or curr == 3)
		
		# Récupérer les skills des voisins déjà assignés
		var neighbor_skills = []
		for neighbor in adjacency_list[curr]:
			if node_skills.has(neighbor) and node_skills[neighbor] != null:
				neighbor_skills.append(node_skills[neighbor])
				
		var chosen_skill = _draft_skill(tier, zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)"""

new_draft_call = """		var zone = _get_zone(pt)
		var hybrid_zone = _get_hybrid_zone(pt)
		var connections = _get_connections_count(curr)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (curr == 1 or curr == 2 or curr == 3)
		
		# Récupérer les skills des voisins déjà assignés
		var neighbor_skills = []
		for neighbor in adjacency_list[curr]:
			if node_skills.has(neighbor) and node_skills[neighbor] != null:
				neighbor_skills.append(node_skills[neighbor])
				
		var chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)"""
content = content.replace(old_draft_call, new_draft_call)

# 3. Update _draft_skill definition and logic
old_draft_def = """func _draft_skill(tier: int, zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = []) -> SkillNodeData:
	var best_candidates = []
	var total_weight = 0.0
	
	var desired_type = SkillNodeData.NodeType.MINOR
	if is_root:
		desired_type = SkillNodeData.NodeType.MINOR
	elif is_leaf:
		desired_type = SkillNodeData.NodeType.KEYSTONE
	elif is_hub:
		desired_type = SkillNodeData.NodeType.NOTABLE
	
	for skill in deck:
		# Vérifier la zone
		var zone_mult = 0.0
		if skill.is_hybrid_exclusive:
			if zone == SkillNodeData.Zone.HYBRID_BARB_MAGE and skill.spawn_in_barb_mage:
				zone_mult = 1.0
			elif zone == SkillNodeData.Zone.HYBRID_MAGE_DUEL and skill.spawn_in_mage_duel:
				zone_mult = 1.0
			elif zone == SkillNodeData.Zone.HYBRID_DUEL_BARB and skill.spawn_in_duel_barb:
				zone_mult = 1.0
			else:
				zone_mult = 0.0
		else:
			if zone == SkillNodeData.Zone.MAGE:
				zone_mult = skill.zone_mage_multiplier
			elif zone == SkillNodeData.Zone.DUELIST:
				zone_mult = skill.zone_duelist_multiplier
			elif zone == SkillNodeData.Zone.BARBARIAN:
				zone_mult = skill.zone_barbarian_multiplier
			else:
				# Les nœuds normaux ne peuvent PAS spawn dans la zone hybride
				zone_mult = 0.0"""

new_draft_def = """func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = []) -> SkillNodeData:
	var best_candidates = []
	var total_weight = 0.0
	
	var desired_type = SkillNodeData.NodeType.MINOR
	if is_root:
		desired_type = SkillNodeData.NodeType.MINOR
	elif is_leaf:
		desired_type = SkillNodeData.NodeType.KEYSTONE
	elif is_hub:
		desired_type = SkillNodeData.NodeType.NOTABLE
	
	for skill in deck:
		# Vérifier la zone
		var zone_mult = 0.0
		if skill.is_hybrid_exclusive:
			if hybrid_zone == SkillNodeData.Zone.HYBRID_BARB_MAGE and skill.spawn_in_barb_mage:
				zone_mult = 1.0
			elif hybrid_zone == SkillNodeData.Zone.HYBRID_MAGE_DUEL and skill.spawn_in_mage_duel:
				zone_mult = 1.0
			elif hybrid_zone == SkillNodeData.Zone.HYBRID_DUEL_BARB and skill.spawn_in_duel_barb:
				zone_mult = 1.0
			else:
				zone_mult = 0.0
		else:
			if strict_zone == SkillNodeData.Zone.MAGE:
				zone_mult = skill.zone_mage_multiplier
			elif strict_zone == SkillNodeData.Zone.DUELIST:
				zone_mult = skill.zone_duelist_multiplier
			elif strict_zone == SkillNodeData.Zone.BARBARIAN:
				zone_mult = skill.zone_barbarian_multiplier
				
			# Malus de 500% (x0.2) si on est dans la zone hybride pour laisser la place aux hybrides exclusifs
			if hybrid_zone != SkillNodeData.Zone.ANY:
				zone_mult *= 0.2"""

content = content.replace(old_draft_def, new_draft_def)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated logic for soft hybrid zones with penalties")
