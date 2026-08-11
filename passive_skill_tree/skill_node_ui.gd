@tool
class_name SkillNodeUI
extends TextureButton

enum NodeState { LOCKED, AVAILABLE, UNLOCKED }

var data: SkillNodeData
var current_state: NodeState = NodeState.LOCKED
var node_index: int = -1 # L'index du point géométrique dans le générateur

signal node_clicked(node: SkillNodeUI)

func _ready():
	# Appliquer l'état initial (LOCKED par défaut) si setup n'est pas appelé
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_state(current_state)
	
	# Connecter les signaux pour le retour visuel
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
func setup(_data: SkillNodeData, _index: int):
	data = _data
	node_index = _index
	
	if data:
		# On ne met plus texture_normal pour pouvoir dessiner l'icône manuellement par-dessus le fond
		# if data.icon != null:
		# 	texture_normal = data.icon
		
		# Créer un Tooltip basique (bulle d'info au survol)
		var tooltip = data.node_name + "\n"
		tooltip += data.description + "\n\n"
		
		for bonus in data.stats_bonuses:
			if bonus == null: continue
			var prefix = "+" if bonus.value >= 0 else ""
			var suffix = "%" if bonus.mod_type == 1 else ""
			tooltip += prefix + str(bonus.value) + suffix + " " + bonus.stat_name + "\n"
			
		tooltip_text = tooltip
		
		# Ajuster la taille en fonction du type
		# On n'utilise plus les propriétés de texture du TextureButton car on dessine manuellement
		# ignore_texture_size = true
		# stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		if data.node_type == SkillNodeData.NodeType.KEYSTONE:
			custom_minimum_size = Vector2(64, 64)
			size = Vector2(64, 64)
		elif data.node_type == SkillNodeData.NodeType.NOTABLE:
			custom_minimum_size = Vector2(48, 48)
			size = Vector2(48, 48)
		else:
			custom_minimum_size = Vector2(32, 32)
			size = Vector2(32, 32)
			
	# Centrer l'image (pivot) après avoir changé la taille
	pivot_offset = size / 2.0
		
	# Au départ, le nœud est verrouillé
	set_state(NodeState.LOCKED)
	queue_redraw()

func set_state(new_state: NodeState):
	current_state = new_state
	match current_state:
		NodeState.LOCKED:
			# Sombre et un peu transparent
			modulate = Color(0.5, 0.5, 0.5, 0.9)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			button_mask = 0
		NodeState.AVAILABLE:
			# Couleurs normales, prêt à être cliqué
			modulate = Color(1.0, 1.0, 1.0, 1.0)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button_mask = MOUSE_BUTTON_MASK_LEFT
		NodeState.UNLOCKED:
			# Un peu doré/brillant pour montrer qu'il est acquis
			modulate = Color(1.2, 1.1, 0.5, 1.0)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			button_mask = 0
	
	queue_redraw()

func _draw():
	var center = size / 2.0
	# On prend un rayon légèrement plus petit pour laisser la place à la bordure
	var radius = (min(size.x, size.y) / 2.0) - 1.0
	
	# Cercle de fond très sombre pour faire ressortir l'icône
	draw_circle(center, radius, Color(0.05, 0.05, 0.08, 0.95))
	
	# Bordure qui change de couleur selon l'état
	var border_color = Color(0.2, 0.2, 0.2, 1.0) # Défaut / Locked
	if current_state == NodeState.AVAILABLE:
		border_color = Color(0.8, 0.8, 0.8, 1.0) # Blanc/Gris clair
	elif current_state == NodeState.UNLOCKED:
		border_color = Color(1.0, 0.8, 0.2, 1.0) # Doré
		
	draw_arc(center, radius, 0, TAU, 32, border_color, 2.0, true)
	
	# 3. Dessiner l'icône PAR-DESSUS le fond !
	if data != null and data.icon != null:
		# On dessine l'icône légèrement plus petite que le cercle pour voir la bordure
		# On garde les proportions de l'image
		var tex_size = data.icon.get_size()
		var target_size = size * 0.7 # L'icône prend 70% de la taille du bouton
		
		# On calcule le ratio pour ne pas déformer l'image (Keep Aspect Centered)
		var scale_factor = min(target_size.x / tex_size.x, target_size.y / tex_size.y)
		var final_size = tex_size * scale_factor
		var icon_pos = center - (final_size / 2.0)
		
		draw_texture_rect(data.icon, Rect2(icon_pos, final_size), false)

func _pressed():
	if current_state == NodeState.AVAILABLE:
		node_clicked.emit(self)

# --- Effets Visuels ---
func _on_mouse_entered():
	if current_state != NodeState.LOCKED:
		# Agrandir légèrement au survol
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)

func _on_mouse_exited():
	# Remettre à la taille normale
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _on_button_down():
	if current_state != NodeState.LOCKED:
		# Rétrécir légèrement quand on clique
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)

func _on_button_up():
	if current_state != NodeState.LOCKED:
		# Remettre à la taille de survol
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
