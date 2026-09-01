@tool
extends Control

signal tree_node_clicked(node_index: int, skill_data: SkillNodeData)

@export var generate_now: bool = false :
	set(val):
		generate_now = false
		generate_tree()

@export_category("Parameters")
## Nombre total de nœuds de l'arbre.
@export var num_nodes: int = 150
## Taille globale de l'arbre (rayon en pixels).
@export var tree_radius: float = 400.0
## Espace minimum entre deux nœuds (empêche les superpositions).
@export var min_node_distance: float = 40.0
@export_range(0.0, 100.0) var cross_link_percent: float = 10.0 # Pourcentage de connexions supplémentaires

@export_category("Equilibrage (Poids & Règles)")
@export_group("Types & Thèmes")
## Force avec laquelle le système tente de placer un Mineur sur un chemin normal.
## (Mettre à 100.0+ pour forcer).
@export var minor_match_multiplier: float = 3.0
## Force avec laquelle le système tente de placer un Notable sur un Carrefour (3+ connexions).
## (Mettre à 100.0+ pour forcer).
@export var notable_match_multiplier: float = 3.0
## Force avec laquelle le système tente de placer une Keystone sur une Impasse.
## (Mettre à 100.0+ pour forcer).
@export var keystone_match_multiplier: float = 3.0
## Force d'infection : Multiplicateur de thème quand le voisin est un MINEUR.
@export var tag_match_multiplier_per_tag_minor: float = 2.5
## Force d'infection : Multiplicateur de thème quand le voisin est un NOTABLE.
@export var tag_match_multiplier_per_tag_notable: float = 6.0
## Force d'infection : Multiplicateur de thème quand le voisin est une KEYSTONE.
@export var tag_match_multiplier_per_tag_keystone: float = 8.0
@export_group("Zones Hybrides")
## Réduit les chances des nœuds normaux dans les zones frontières (laissant la place aux Hybrides Exclusifs).
@export_range(0.0, 1.0) var hybrid_penalty_multiplier: float = 0.2
@export_group("Impasses (Dead Ends)")
## Plus une impasse est longue, plus une Keystone a de chance d'apparaître au bout.
@export_range(0.0, 10.0) var dead_end_keystone_multiplier_per_depth: float = 2.5
## Interdit l'apparition de nœuds Mineurs sur les X dernières cases d'une très longue impasse.
@export var dead_end_minor_cutoff_depth: int = 2

@export_category("Zones & Hybrides")
@export var hybrid_zone_width_degrees: float = 20.0 :
	set(val):
		hybrid_zone_width_degrees = val
		queue_redraw()

@export_category("Starter Nodes")
@export var starter_nodes_mage: Array[SkillNodeData] = []
@export var starter_nodes_duelist: Array[SkillNodeData] = []
@export var starter_nodes_barbarian: Array[SkillNodeData] = []

@export_category("UI & Données")
## Cochez pour générer un rapport complet du contenu du Skill Deck dans la console (Output).
@export var analyze_skill_deck: bool = false :
	set(val):
		analyze_skill_deck = false
		if Engine.is_editor_hint() and val == true:
			_print_deck_statistics()
			
func _print_deck_statistics() -> void:
	print("\n=======================================================")
	print("📊 ANALYSE DU SKILL DECK (", skill_deck.size(), " Noeuds)")
	print("=======================================================")
	
	var stats = {
		"MINOR": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0},
		"NOTABLE": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0},
		"KEYSTONE": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0}
	}
	
	for skill in skill_deck:
		if skill == null: continue
		var type_str = "MINOR"
		if skill.node_type == 1: type_str = "NOTABLE"
		elif skill.node_type == 2: type_str = "KEYSTONE"
		
		if skill.is_hybrid_exclusive:
			stats[type_str]["hybrid_exclusive"] += 1
			continue
			
		var b = skill.zone_barbarian_multiplier > 0.0
		var m = skill.zone_mage_multiplier > 0.0
		var d = skill.zone_duelist_multiplier > 0.0
		
		if b and not m and not d: stats[type_str]["barb"] += 1
		elif not b and m and not d: stats[type_str]["mage"] += 1
		elif not b and not m and d: stats[type_str]["duel"] += 1
		elif b and m and not d: stats[type_str]["barb_mage"] += 1
		elif not b and m and d: stats[type_str]["mage_duel"] += 1
		elif b and not m and d: stats[type_str]["duel_barb"] += 1
		elif b and m and d: stats[type_str]["all_3"] += 1
		
	for type in ["MINOR", "NOTABLE", "KEYSTONE"]:
		var t_barb = stats[type]["barb"] + stats[type]["barb_mage"] + stats[type]["duel_barb"] + stats[type]["all_3"]
		var t_mage = stats[type]["mage"] + stats[type]["barb_mage"] + stats[type]["mage_duel"] + stats[type]["all_3"]
		var t_duel = stats[type]["duel"] + stats[type]["duel_barb"] + stats[type]["mage_duel"] + stats[type]["all_3"]
		
		print("\n--- ", type, "S ---")
		print(" - Exclusif BARBARE : ", stats[type]["barb"])
		print(" - Exclusif MAGE    : ", stats[type]["mage"])
		print(" - Exclusif DUELIST : ", stats[type]["duel"])
		print(" - 2 Zones (Barb+Mage) : ", stats[type]["barb_mage"])
		print(" - 2 Zones (Mage+Duel) : ", stats[type]["mage_duel"])
		print(" - 2 Zones (Duel+Barb) : ", stats[type]["duel_barb"])
		print(" - 3 Zones (ANY)       : ", stats[type]["all_3"])
		print(" - HYBRID Exclusif     : ", stats[type]["hybrid_exclusive"])
		print("   => TOTAL DISPO EN ZONE BARBARE : ", t_barb)
		print("   => TOTAL DISPO EN ZONE MAGE    : ", t_mage)
		print("   => TOTAL DISPO EN ZONE DUELIST : ", t_duel)
		
	print("=======================================================\n")


@export var tree_seed: int = 12345 # Graine de génération pour avoir le même arbre
@export var node_ui_scene: PackedScene
@export var skill_deck: Array[SkillNodeData] = []

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

# --- Nouvelles variables pour l'interaction ---
var ui_nodes: Array[SkillNodeUI] = []
var adjacency_list: Dictionary = {}
var node_skills: Dictionary = {} # Associe un index de noeud à sa compétence
var edge_lines: Dictionary = {} # NOUVEAU: Pour garder une référence aux Line2D

var is_dragging: bool = false
var last_mouse_pos: Vector2
@export_category("Navigation & Zoom")
@export var zoom_min: float = 0.6
@export var zoom_max: float = 2.5
@export var zoom_speed: float = 0.1

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
		
	# On utilise le CanvasLayer parent comme "Caméra" (c'est la meilleure méthode pour l'UI)
	var canvas = get_parent()
	if not canvas is CanvasLayer:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
			else:
				is_dragging = false
				
		# Zoom in/out
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom = clamp(canvas.scale.x + zoom_speed, zoom_min, zoom_max)
			var mouse_pos = get_viewport().get_mouse_position()
			canvas.offset = mouse_pos - (mouse_pos - canvas.offset) * (new_zoom / canvas.scale.x)
			canvas.scale = Vector2(new_zoom, new_zoom)
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom = clamp(canvas.scale.x - zoom_speed, zoom_min, zoom_max)
			var mouse_pos = get_viewport().get_mouse_position()
			canvas.offset = mouse_pos - (mouse_pos - canvas.offset) * (new_zoom / canvas.scale.x)
			canvas.scale = Vector2(new_zoom, new_zoom)
			
	elif event is InputEventMouseMotion and is_dragging:
		# Sécurité : si on bouge la souris mais qu'on ne maintient plus le clic physique, on arrête le drag (anti-accrochage)
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			is_dragging = false
			return
			
		# Panning (Déplacement)
		# UTILISER event.relative !! Sinon ça crée une boucle infinie car l'UI bouge sous la souris !
		var new_offset = canvas.offset + event.relative
		
		# Mathématiques pures : on calcule exactement les bords pour que le Control (-1000 à viewport+1000)
		# couvre toujours l'écran [0, viewport], peu importe le zoom !
		var margin = 1000.0
		var viewport_size = get_viewport_rect().size
		
		var max_x = margin * canvas.scale.x
		var min_x = viewport_size.x * (1.0 - canvas.scale.x) - margin * canvas.scale.x
		
		var max_y = margin * canvas.scale.y
		var min_y = viewport_size.y * (1.0 - canvas.scale.y) - margin * canvas.scale.y
		
		# Sécurité anti-glitch si l'écran est géant (ultra-wide)
		if min_x > max_x:
			var mid = (min_x + max_x) / 2.0
			min_x = mid
			max_x = mid
		if min_y > max_y:
			var mid = (min_y + max_y) / 2.0
			min_y = mid
			max_y = mid
			
		new_offset.x = clamp(new_offset.x, min_x, max_x)
		new_offset.y = clamp(new_offset.y, min_y, max_y)
		
		canvas.offset = new_offset

func _ready():
	# Agrandir le panneau BEAUCOUP plus que la limite de caméra (3000 pixels) 
	# pour créer une zone morte géante qui captera TOUJOURS la souris.
	offset_left = -3000
	offset_top = -3000
	offset_right = 3000
	offset_bottom = 3000

	# Si on n'est pas dans l'éditeur (donc on lance le jeu), on génère l'arbre automatiquement
	if not Engine.is_editor_hint():
		generate_tree()

func generate_tree():
	if not is_inside_tree():
		return
	var current_seed = tree_seed
	if current_seed == 0:
		randomize()
		current_seed = randi()
		print("Génération avec une seed aléatoire : ", current_seed)
		
	seed(current_seed)
	if noise_map:
		noise_map.seed = current_seed
		
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
	_ensure_region_connectivity(SkillNodeData.Zone.MAGE)
	_ensure_region_connectivity(SkillNodeData.Zone.DUELIST)
	_ensure_region_connectivity(SkillNodeData.Zone.BARBARIAN)
		
	# --- ETAPE 5 : Génération de l'image de fond du bruit ---
	if noise_map != null:
		_generate_noise_texture()
	else:
		noise_texture = null
		
	# --- ETAPE 6 : Construction de l'interface interactive ---
	_build_interactive_tree()
		
	# Demande à Godot de redessiner l'UI (le fond)
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
	
func _ensure_region_connectivity(target_zone: int) -> void:
	var region_nodes = []
	for i in range(1, points.size()): # Skip le centre
		if _get_zone(points[i]) == target_zone:
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
		
	# Dessiner le fond (qui montre les limites du Control) en gris clair transparent
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.8, 0.8, 0.1))
		
	# On centre par rapport à l'écran, peu importe la taille ou la position décalée du Control
	var center_offset = Vector2(3960, 3540)
	
	# Dessiner la texture de bruit en arrière-plan
	if show_noise_background and noise_texture != null:
		var tex_pos = center_offset - Vector2(tree_radius, tree_radius)
		draw_texture(noise_texture, tex_pos)
	
	# Lignes de séparation (120 degrés)
	var hybrid_rad = deg_to_rad(hybrid_zone_width_degrees) / 2.0
	for angle in [-PI / 2.0, PI / 6.0, 5.0 * PI / 6.0]:
		var dir_mid = Vector2(cos(angle), sin(angle)) * tree_radius
		var dir_left = Vector2(cos(angle - hybrid_rad), sin(angle - hybrid_rad)) * tree_radius
		var dir_right = Vector2(cos(angle + hybrid_rad), sin(angle + hybrid_rad)) * tree_radius
		
		# Ligne centrale (optionnelle, fine)
		draw_line(center_offset, center_offset + dir_mid, Color(1, 1, 1, 0.1), 1.0, true)
		# Frontières de la zone hybride
		draw_line(center_offset, center_offset + dir_left, Color(1, 1, 0, 0.4), 2.0, true)
		draw_line(center_offset, center_offset + dir_right, Color(1, 1, 0, 0.4), 2.0, true)
	
	# Cercles concentriques (Tiers)
	# Utiliser 0.5 et 0.8 équilibre beaucoup mieux les aires de chaque zone (environ 25% / 39% / 36% des points)
	draw_arc(center_offset, tree_radius * 0.5, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 1.5, true)
	draw_arc(center_offset, tree_radius * 0.8, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 1.5, true)
	draw_arc(center_offset, tree_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.1), 1.0, true)

# ==========================================
# INTERFACE ET DRAFTING (L'ARBRE INTERACTIF)
# ==========================================

func _build_interactive_tree():
	# Nettoyer les anciens noeuds UI et Lignes
	for child in get_children():
		child.queue_free()
		
	ui_nodes.clear()
	adjacency_list.clear()
	node_skills.clear()
	
	# Construire le graphe d'adjacence pour propager les déblocages
	for i in range(points.size()):
		adjacency_list[i] = []
		
	for edge in edges:
		if not adjacency_list[edge.x].has(edge.y):
			adjacency_list[edge.x].append(edge.y)
		if not adjacency_list[edge.y].has(edge.x):
			adjacency_list[edge.y].append(edge.x)
			
	if node_ui_scene == null:
		push_warning("Veuillez assigner la scène SkillNodeUI dans l'inspecteur !")
		return
		
	# On centre par rapport à l'écran
	var center_offset = Vector2(3960, 3540)
	
	# 1. Créer les lignes visuelles (Line2D)
	edge_lines.clear()
	for edge in edges:
		var line = Line2D.new()
		line.add_point(points[edge.x] + center_offset)
		line.add_point(points[edge.y] + center_offset)
		line.width = 4.0
		line.default_color = Color(0.4, 0.4, 0.5, 0.5) # Gris par défaut
		add_child(line)
		
		# On crée une clé unique "min_max" pour retrouver la ligne plus tard
		var min_idx = min(edge.x, edge.y)
		var max_idx = max(edge.x, edge.y)
		edge_lines[str(min_idx) + "_" + str(max_idx)] = line
		
	# 2. Cloner le deck pour le modifier pendant la génération
	var available_deck = []
	for skill in skill_deck:
		if skill != null:
			# On duplique la ressource en mémoire pour pouvoir modifier max_occurrences
			# sans altérer le fichier original sauvegardé sur le disque
			var skill_copy = skill.duplicate()
			available_deck.append(skill_copy)
	
	# 2.5. Pré-calculer la longueur des impasses (pour les feuilles uniquement)
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
				
			leaf_dead_end_length[i] = chain_length

	# 3. NOUVEAU: Parcourir le graphe avec un ordre de priorité !
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
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, starter_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])
			else:
				chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])
		else:
			chosen_skill = _draft_skill(tier, zone, hybrid_zone, available_deck, is_leaf, is_hub, is_root, neighbor_skills, leaf_dead_end_length[curr])
		
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
		
		ui_nodes.append(ui)


	# 4. Initialisation des états
	# On fait ça en mode "call_deferred" pour être sûr que tout est bien ajouté à l'arbre
	call_deferred("_init_tree_states")

func _init_tree_states():
	if ui_nodes.size() > 0:
		# Le noeud central (0) est débloqué
		ui_nodes[0].set_state(SkillNodeUI.NodeState.UNLOCKED)
		# Ses voisins deviennent disponibles
		for neighbor in adjacency_list[0]:
			ui_nodes[neighbor].set_state(SkillNodeUI.NodeState.AVAILABLE)
			
		# Mise à jour des lignes pour les noeuds initiaux (et futurs chargements de sauvegarde)
		for i in range(ui_nodes.size()):
			if ui_nodes[i].current_state == SkillNodeUI.NodeState.UNLOCKED:
				for neighbor in adjacency_list[i]:
					if ui_nodes[neighbor].current_state == SkillNodeUI.NodeState.UNLOCKED:
						var edge_key = str(min(i, neighbor)) + "_" + str(max(i, neighbor))
						if edge_lines.has(edge_key):
							edge_lines[edge_key].default_color = Color(1.0, 1.0, 1.0, 1.0)
							edge_lines[edge_key].width = 6.0

func _on_ui_node_clicked(ui: SkillNodeUI, node_index: int):
	# On dit au Component (s'il écoute) que ce noeud veut être débloqué
	if ui.current_state == SkillNodeUI.NodeState.AVAILABLE:
		tree_node_clicked.emit(node_index, node_skills.get(node_index, null))

func unlock_node(node_index: int):
	if node_index >= 0 and node_index < ui_nodes.size():
		ui_nodes[node_index].set_state(SkillNodeUI.NodeState.UNLOCKED)
		
		# Rendre les voisins disponibles (s'ils sont encore verrouillés)
		for neighbor in adjacency_list[node_index]:
			if ui_nodes[neighbor].current_state == SkillNodeUI.NodeState.LOCKED:
				ui_nodes[neighbor].set_state(SkillNodeUI.NodeState.AVAILABLE)
				
			# Mettre à jour la ligne si le voisin est AUSSI débloqué
			if ui_nodes[neighbor].current_state == SkillNodeUI.NodeState.UNLOCKED:
				var edge_key = str(min(node_index, neighbor)) + "_" + str(max(node_index, neighbor))
				if edge_lines.has(edge_key):
					edge_lines[edge_key].default_color = Color(1.0, 1.0, 1.0, 1.0)
					edge_lines[edge_key].width = 6.0

func _draft_skill(tier: int, strict_zone: int, hybrid_zone: int, deck: Array, is_leaf: bool, is_hub: bool, is_root: bool, neighbor_skills: Array = [], dead_end_length: int = 0) -> SkillNodeData:
	var best_candidates = []
	var total_weight = 0.0
	var fallback_candidates = []
	var fallback_total_weight = 0.0
	
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
				
			# Malus pour laisser la place aux hybrides exclusifs
			if hybrid_zone != SkillNodeData.Zone.ANY:
				zone_mult *= hybrid_penalty_multiplier
			
		var weight = skill.base_spawn_weight * zone_mult
		if tier == 1: weight *= skill.tier_1_multiplier
		elif tier == 2: weight *= skill.tier_2_multiplier
		elif tier == 3: weight *= skill.tier_3_multiplier
		
		if weight <= 0.0:
			continue
			
		# Règle stricte : les 3 premiers points DOIVENT être mineurs
		if is_root and skill.node_type != SkillNodeData.NodeType.MINOR:
			continue
			
		# --- INTERDIRE LES KEYSTONES COTE A COTE ---
		var is_banned_keystone = false
		if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
			for n_skill in neighbor_skills:
				if n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					is_banned_keystone = true
					break
		# -------------------------------------------
		
		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			if desired_type == SkillNodeData.NodeType.MINOR:
				type_multiplier = minor_match_multiplier
			elif desired_type == SkillNodeData.NodeType.NOTABLE:
				type_multiplier = notable_match_multiplier
			elif desired_type == SkillNodeData.NodeType.KEYSTONE:
				type_multiplier = keystone_match_multiplier
			
		weight *= type_multiplier
		
		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
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
					
				var force: float = 2.5
				if tag_match_multiplier_per_tag_minor != null: force = tag_match_multiplier_per_tag_minor
				if n_skill.node_type == SkillNodeData.NodeType.NOTABLE:
					force = 6.0
					if tag_match_multiplier_per_tag_notable != null: force = tag_match_multiplier_per_tag_notable
				elif n_skill.node_type == SkillNodeData.NodeType.KEYSTONE:
					force = 8.0
					if tag_match_multiplier_per_tag_keystone != null: force = tag_match_multiplier_per_tag_keystone
					
				thematic_multiplier += force * count
		weight *= thematic_multiplier
		# ----------------------------------------
		
		if weight > 0:
			if is_banned_minor or is_banned_keystone:
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
			return null
		
	# Roulette
	var roll = randf() * total_weight
	var current = 0.0
	for candidate in best_candidates:
		current += candidate.weight
		if roll <= current:
			return candidate.skill
			
	return best_candidates.back().skill

func _get_zone(pos: Vector2) -> int:
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
		
	return SkillNodeData.Zone.ANY

func _get_tier(pos: Vector2) -> int:
	var dist = pos.length()
	if dist <= tree_radius * 0.5:
		return 1
	elif dist <= tree_radius * 0.8:
		return 2
	return 3

func _get_connections_count(idx: int) -> int:
	var count = 0
	for e in edges:
		if e.x == idx or e.y == idx:
			count += 1
	return count
