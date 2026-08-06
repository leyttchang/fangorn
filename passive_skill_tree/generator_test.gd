@tool
extends Control

@export var generate_now: bool = false :
	set(val):
		generate_now = false
		generate_tree()

@export_category("Parameters")
@export var num_nodes: int = 150
@export var tree_radius: float = 400.0
@export var min_node_distance: float = 40.0
@export_range(0.0, 100.0) var cross_link_percent: float = 10.0 # Pourcentage de connexions supplémentaires

@export_category("Noise")
@export var show_noise_background: bool = true :
	set(val):
		show_noise_background = val
		queue_redraw()
@export var noise_map: FastNoiseLite
@export_range(0.0, 1.0) var noise_influence: float = 0.5 # 0.0 = aucun effet du bruit, 1.0 = respect total du bruit
@export_range(0.1, 10.0) var noise_contrast: float = 1.0 # 1.0 = normal, > 1.0 = plus de contraste (plus de noir pur et de blanc pur)

var points: PackedVector2Array = []
var edges: Array[Vector2i] = [] # stocke les indices des points connectés (u, v)
var noise_texture: ImageTexture = null

func _ready():
	pass

func generate_tree():
	points.clear()
	edges.clear()
	
	# --- ETAPE 1 : Placement des points (Rejection Sampling) ---
	points.append(Vector2.ZERO) # Le noeud central (départ)
	
	var angle1 = -PI / 2.0
	var angle2 = angle1 + (TAU / 3.0)
	var angle3 = angle1 + (TAU * 2.0 / 3.0)
	
	# Ajouter les 3 points de départ fixes (au milieu de chaque zone)
	var mid_angle1 = angle1 + (TAU / 6.0)
	var mid_angle2 = angle2 + (TAU / 6.0)
	var mid_angle3 = angle3 + (TAU / 6.0)
	
	points.append(Vector2(cos(mid_angle1), sin(mid_angle1)) * min_node_distance)
	points.append(Vector2(cos(mid_angle2), sin(mid_angle2)) * min_node_distance)
	points.append(Vector2(cos(mid_angle3), sin(mid_angle3)) * min_node_distance)
	
	var attempts = 0
	var max_attempts = num_nodes * 200 # Augmenté car on va rejeter plus de points
	
	while points.size() < num_nodes and attempts < max_attempts:
		attempts += 1
		var angle = randf() * TAU
		# sqrt(randf()) pour une distribution uniforme dans le cercle
		var dist = sqrt(randf()) * tree_radius
		var new_pt = Vector2(cos(angle), sin(angle)) * dist
		
		# --- VERIFICATION DU BRUIT ---
		var accept_chance = 1.0
		if noise_map != null:
			# Bulletproof cast to float
			var nv = float(noise_map.get_noise_2d(new_pt.x, new_pt.y))
			# On inverse : le noir (-1.0) devient 1.0 (attire) et le blanc (1.0) devient 0.0 (repousse)
			var normalized_noise = (-nv + 1.0) / 2.0
			
			var nc = float(noise_contrast)
			# Appliquer le contraste
			normalized_noise = clamp((normalized_noise - 0.5) * nc + 0.5, 0.0, 1.0)
			
			var ni = float(noise_influence)
			# On interpole selon l'influence souhaitée
			accept_chance = lerp(1.0, normalized_noise, ni)
			
		if randf() > accept_chance:
			continue # Point rejeté par le bruit, on saute à l'essai suivant
		
		# Vérifier si le point est trop proche d'un autre
		var too_close = false
		for p in points:
			if p.distance_to(new_pt) < min_node_distance:
				too_close = true
				break
		
		if not too_close:
			points.append(new_pt)
			
	# --- ETAPE 2 : Triangulation de Delaunay ---
	var delaunay_indices = Geometry2D.triangulate_delaunay(points)
	if delaunay_indices.size() == 0:
		queue_redraw()
		return
		
	# Extraire les arrêtes uniques et calculer leur longueur
	var all_edges = []
	for i in range(0, delaunay_indices.size(), 3):
		var p1 = delaunay_indices[i]
		var p2 = delaunay_indices[i+1]
		var p3 = delaunay_indices[i+2]
		
		_add_edge_if_unique(all_edges, p1, p2)
		_add_edge_if_unique(all_edges, p2, p3)
		_add_edge_if_unique(all_edges, p3, p1)
		
	# Filtrer pour s'assurer que le centre (0) ne se connecte qu'à 1, 2, et 3
	var filtered_edges = []
	for edge in all_edges:
		if edge.u == 0 or edge.v == 0:
			if (edge.u == 0 and edge.v in [1, 2, 3]) or (edge.v == 0 and edge.u in [1, 2, 3]):
				filtered_edges.append(edge)
		else:
			filtered_edges.append(edge)
		
	# Trier les arrêtes de la plus courte à la plus longue
	filtered_edges.sort_custom(func(a, b): return a.length < b.length)
	
	# --- ETAPE 3 : Kruskal's MST (Arbre pur) ---
	var parent = []
	for i in range(points.size()):
		parent.append(i)
		
	var mst_edges = []
	var remaining_edges = []
	
	for edge in filtered_edges:
		var root1 = _find(parent, edge.u)
		var root2 = _find(parent, edge.v)
		if root1 != root2:
			# Union
			parent[root1] = root2
			mst_edges.append(edge)
		else:
			# Ces arrêtes créeraient une boucle
			remaining_edges.append(edge)
			
	for e in mst_edges:
		edges.append(Vector2i(e.u, e.v))
		
	# --- ETAPE 4 : Hybridation (Cross-linking) ---
	# On mélange les arrêtes restantes pour en prendre au hasard
	remaining_edges.shuffle()
	var cross_link_count = int(mst_edges.size() * (cross_link_percent / 100.0))
	for i in range(min(cross_link_count, remaining_edges.size())):
		edges.append(Vector2i(remaining_edges[i].u, remaining_edges[i].v))
		
	# --- ETAPE 4.5 : Sécurité de connectivité par région ---
	_ensure_region_connectivity(Color.CORNFLOWER_BLUE)
	_ensure_region_connectivity(Color.PALE_GREEN)
	_ensure_region_connectivity(Color.INDIAN_RED)
		
	# --- ETAPE 5 : Génération de l'image de fond du bruit ---
	if noise_map != null:
		_generate_noise_texture()
	else:
		noise_texture = null
		
	# Demande à Godot de redessiner l'UI
	queue_redraw()

func _generate_noise_texture():
	var img_size = int(tree_radius * 2.0)
	# On crée une image pour stocker les pixels de bruit (Godot 4.x)
	var img = Image.create_empty(img_size, img_size, false, Image.FORMAT_RGBA8)
		
	for y in range(img_size):
		for x in range(img_size):
			# Convertir la position du pixel en coordonnées de l'arbre
			var px = float(x) - tree_radius
			var py = float(y) - tree_radius
			
			var nv = float(noise_map.get_noise_2d(px, py))
			# On n'inverse pas le visuel, ainsi les zones de spawn apparaîtront en noir
			var norm = (nv + 1.0) / 2.0
			
			var nc = float(noise_contrast)
			# Appliquer le contraste pour l'affichage visuel aussi
			norm = clamp((norm - 0.5) * nc + 0.5, 0.0, 1.0)
			
			# Noir et blanc avec un peu de transparence (0.8 au lieu de 0.4) pour que le blanc ressorte mieux
			img.set_pixel(x, y, Color(norm, norm, norm, 0.8))
			
	noise_texture = ImageTexture.create_from_image(img)

func _add_edge_if_unique(edge_list: Array, u: int, v: int) -> void:
	var min_idx = min(u, v)
	var max_idx = max(u, v)
	
	for e in edge_list:
		if e.u == min_idx and e.v == max_idx:
			return # L'arrête existe déjà
	
	var length = points[u].distance_to(points[v])
	edge_list.append({"u": min_idx, "v": max_idx, "length": length})
	
func _ensure_region_connectivity(target_color: Color) -> void:
	var region_nodes = []
	for i in range(1, points.size()): # Skip le centre
		if _get_region_color(points[i]) == target_color:
			region_nodes.append(i)
			
	if region_nodes.size() <= 1:
		return
		
	var adj = {}
	for node in region_nodes:
		adj[node] = []
		
	for edge in edges:
		if edge.x in adj and edge.y in adj:
			adj[edge.x].append(edge.y)
			adj[edge.y].append(edge.x)
			
	var visited = {}
	for node in region_nodes:
		visited[node] = false
		
	var components = []
	for node in region_nodes:
		if not visited[node]:
			var comp = []
			var q = [node]
			visited[node] = true
			while q.size() > 0:
				var curr = q.pop_front()
				comp.append(curr)
				for neighbor in adj[curr]:
					if not visited[neighbor]:
						visited[neighbor] = true
						q.push_back(neighbor)
			components.append(comp)
			
	# Tant qu'on a plus d'un groupe isolé dans la même couleur, on les relie
	while components.size() > 1:
		var comp_a = components[0]
		var comp_b = components[1]
		
		var min_dist = INF
		var best_u = -1
		var best_v = -1
		
		for u in comp_a:
			for v in comp_b:
				var d = points[u].distance_squared_to(points[v])
				if d < min_dist:
					min_dist = d
					best_u = u
					best_v = v
					
		if best_u != -1 and best_v != -1:
			edges.append(Vector2i(best_u, best_v))
			
		for node in comp_b:
			comp_a.append(node)
		components.remove_at(1)

# Algorithme Union-Find avec compression de chemin
func _find(parent: Array, i: int) -> int:
	if parent[i] == i:
		return i
	var root = _find(parent, parent[i])
	parent[i] = root 
	return root

func _draw():
	if points.size() == 0:
		return
		
	var center_offset = size / 2.0
	
	# Dessiner la texture de bruit en arrière-plan
	if show_noise_background and noise_texture != null:
		var tex_pos = center_offset - Vector2(tree_radius, tree_radius)
		draw_texture(noise_texture, tex_pos)
	
	# Lignes de séparation (120 degrés)
	var angle1 = -PI / 2.0
	var angle2 = angle1 + (TAU / 3.0)
	var angle3 = angle1 + (TAU * 2.0 / 3.0)
	
	var dir1 = Vector2(cos(angle1), sin(angle1)) * tree_radius
	var dir2 = Vector2(cos(angle2), sin(angle2)) * tree_radius
	var dir3 = Vector2(cos(angle3), sin(angle3)) * tree_radius
	
	draw_line(center_offset, center_offset + dir1, Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(center_offset, center_offset + dir2, Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(center_offset, center_offset + dir3, Color(1, 1, 1, 0.3), 1.0, true)
	
	# Dessiner les lignes
	for edge in edges:
		var p1 = points[edge.x] + center_offset
		var p2 = points[edge.y] + center_offset
		draw_line(p1, p2, Color(0.4, 0.4, 0.5, 0.8), 2.0, true)
		
	# Dessiner les noeuds
	for i in range(points.size()):
		var p = points[i]
		var draw_p = p + center_offset
		if i == 0:
			draw_circle(draw_p, 10.0, Color.GOLD) # Centre
		else:
			draw_circle(draw_p, 6.0, _get_region_color(p))

func _get_region_color(pos: Vector2) -> Color:
	var angle = pos.angle() # De -PI à PI
	
	# angle1 = -PI/2 (-1.57)
	# angle2 = PI/6 (0.52)
	# angle3 = 5*PI/6 (2.61)
	
	# En haut à droite (Bleu) : entre -PI/2 et PI/6
	if angle >= -PI/2.0 and angle < PI/6.0:
		return Color.CORNFLOWER_BLUE
		
	# En bas (Vert) : entre PI/6 et 5*PI/6
	if angle >= PI/6.0 and angle < 5.0*PI/6.0:
		return Color.PALE_GREEN
		
	# En haut à gauche (Rouge) : le reste
	return Color.INDIAN_RED
