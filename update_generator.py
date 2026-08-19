with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_bfs = """	# 3. NOUVEAU: Parcourir le graphe depuis le centre (BFS) pour propager les thèmes
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
		var hybrid_zone = _get_hybrid_zone(pt)
		var connections = _get_connections_count(curr)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (curr == 1 or curr == 2 or curr == 3)"""

new_priority = """	# 3. NOUVEAU: Parcourir le graphe avec un ordre de priorité !
	# Racines -> Feuilles (Impasses) -> Carrefours -> Le reste
	var roots = []
	var leaves = []
	var hubs = []
	var normals = []
	
	for i in range(1, points.size()):
		var conns = _get_connections_count(i)
		if i == 1 or i == 2 or i == 3:
			roots.append(i)
		elif conns == 1:
			leaves.append(i)
		elif conns >= 3:
			hubs.append(i)
		else:
			normals.append(i)
			
	leaves.shuffle()
	hubs.shuffle()
	normals.shuffle()
			
	var processing_order = roots + leaves + hubs + normals
	node_skills[0] = null
	
	for curr in processing_order:
		var pt = points[curr]
		var tier = _get_tier(pt)
		var zone = _get_zone(pt)
		var hybrid_zone = _get_hybrid_zone(pt)
		var connections = _get_connections_count(curr)
		var is_leaf = (connections == 1)
		var is_hub = (connections >= 3)
		var is_root = (curr == 1 or curr == 2 or curr == 3)"""

content = content.replace(old_bfs, new_priority)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator_test.gd with Priority Ordering")
