import re

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Replace 3. Placer les boutons
old_loop = """	# 3. Placer les boutons
	for i in range(points.size()):
		var pt = points[i]
		var tier = _get_tier(pt)
		var zone = _get_zone(pt)
		var connections = _get_connections_count(i)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (i == 1 or i == 2 or i == 3)
		
		# Spécial: le noeud 0 est le point de départ
		var chosen_skill = null
		if i != 0:
			chosen_skill = _draft_skill(tier, zone, available_deck, is_leaf, is_hub, is_root)
			
		var ui = node_ui_scene.instantiate() as SkillNodeUI
		add_child(ui)
		ui.position = pt + center_offset - (ui.size / 2.0)
		ui.setup(chosen_skill, i)
		ui.node_clicked.connect(_on_ui_node_clicked.bind(i))
		
		ui_nodes.append(ui)
		node_skills[i] = chosen_skill
		
		# Si on a pioché une compétence, on réduit son compteur
		if chosen_skill != null:
			chosen_skill.max_occurrences -= 1
			if chosen_skill.max_occurrences <= 0:
				available_deck.erase(chosen_skill)"""

new_loop = """	# 3. NOUVEAU: Parcourir le graphe depuis le centre (BFS) pour propager les thèmes
	var queue = [0]
	var visited = {0: true}
	
	node_skills[0] = null
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		
		# On cherche les voisins pour continuer le parcours
		for neighbor in adjacency_list[curr]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
				
		if curr == 0:
			continue
			
		var pt = points[curr]
		var tier = _get_tier(pt)
		var zone = _get_zone(pt)
		var connections = _get_connections_count(curr)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (curr == 1 or curr == 2 or curr == 3)
		
		# Récupérer les skills des voisins déjà assignés
		var neighbor_skills = []
		for neighbor in adjacency_list[curr]:
			if node_skills.has(neighbor) and node_skills[neighbor] != null:
				neighbor_skills.append(node_skills[neighbor])
				
		var chosen_skill = _draft_skill(tier, zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)
		
		node_skills[curr] = chosen_skill
		
		if chosen_skill != null:
			chosen_skill.max_occurrences -= 1
			if chosen_skill.max_occurrences <= 0:
				available_deck.erase(chosen_skill)
				
	# 4. Placer les boutons
	for i in range(points.size()):
		var pt = points[i]
		var chosen_skill = node_skills.get(i, null)
		
		var ui = node_ui_scene.instantiate() as SkillNodeUI
		add_child(ui)
		ui.position = pt + center_offset - (ui.size / 2.0)
		ui.setup(chosen_skill, i)
		ui.node_clicked.connect(_on_ui_node_clicked.bind(i))
		
		ui_nodes.append(ui)"""

content = content.replace(old_loop, new_loop)

# Update draft skill
old_draft_def = "func _draft_skill(tier: int, zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool) -> SkillNodeData:"
new_draft_def = "func _draft_skill(tier: int, zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = []) -> SkillNodeData:"
content = content.replace(old_draft_def, new_draft_def)

# Find weight calculation and inject thematic mult
old_weight = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = 3.0 # On favorise le type idéal pour cet emplacement, mais sans excès
			
		weight *= type_multiplier
		
		if weight > 0:"""

new_weight = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = 3.0 # On favorise le type idéal pour cet emplacement, mais sans excès
			
		weight *= type_multiplier
		
		# --- MULTIPLICATEUR THEMATIQUE ---
		var thematic_multiplier = 1.0
		if skill.node_type != SkillNodeData.NodeType.KEYSTONE:
			for n_skill in neighbor_skills:
				for mod in skill.modifiers:
					for n_mod in n_skill.modifiers:
						if mod.stat_name == n_mod.stat_name:
							thematic_multiplier += 4.0 # Boost énorme si on partage une stat avec le voisin parent !
		weight *= thematic_multiplier
		# ---------------------------------
		
		if weight > 0:"""

content = content.replace(old_weight, new_weight)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated successfully")
