with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Exports
export_insertion = """@export_category("Starter Nodes")
@export var starter_nodes_mage: Array[SkillNodeData] = []
@export var starter_nodes_duelist: Array[SkillNodeData] = []
@export var starter_nodes_barbarian: Array[SkillNodeData] = []

@export_category("UI & Données")"""

content = content.replace("@export_category(\"UI & Données\")", export_insertion)

# 2. Modify BFS loop
old_draft_call = """		var zone = _get_zone(pt)
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
				
		var chosen_skill = null
		if is_root:
			var starter_deck = []
			var source_array = []
			if zone == SkillNodeData.Zone.MAGE: source_array = starter_nodes_mage
			elif zone == SkillNodeData.Zone.DUELIST: source_array = starter_nodes_duelist
			elif zone == SkillNodeData.Zone.BARBARIAN: source_array = starter_nodes_barbarian
			
			for skill in source_array:
				if skill != null:
					starter_deck.append(skill.duplicate())
					
			if starter_deck.size() > 0:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills)
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills)"""

content = content.replace(old_draft_call, new_draft_call)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator_test.gd with starter nodes")
