@tool
class_name SkillNodeUI
extends TextureButton

enum NodeState { LOCKED, AVAILABLE, UNLOCKED }

var data: SkillNodeData
var current_state: NodeState = NodeState.LOCKED
var node_index: int = -1 # L'index du point géométrique dans le générateur

var _base_tooltip: String = ""
var _is_hovered: bool = false
var _hover_tween: Tween = null
var _feedback_tween: Tween = null

signal node_clicked(node: SkillNodeUI)
signal node_right_clicked(node: SkillNodeUI)

func _ready() -> void:
	# Appliquer l'état initial (LOCKED par défaut) si setup n'est pas appelé
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_state(current_state)

	# Connecter les signaux pour le retour visuel
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func setup(p_data: SkillNodeData, p_index: int) -> void:
	data = p_data
	node_index = p_index
	_base_tooltip = ""

	if data != null:
		# Créer le texte de base du Tooltip (bulle d'info au survol)
		var tooltip: String = data.node_name + "\n"
		if not data.description.strip_edges().is_empty():
			tooltip += data.description + "\n\n"
		else:
			tooltip += "\n"

		for bonus: StatModifierData in data.stats_bonuses:
			if bonus == null:
				continue

			var stat_name: String = bonus.stat_name.capitalize().replace("_", " ")
			var is_percent_stat: bool = bonus.stat_name in GameData.PERCENT_STATS
			var text: String = ""

			if is_percent_stat:
				var prefix: String = "+" if bonus.value >= 0.0 else ""
				if bonus.mod_type == StatModifierData.ModType.FLAT:
					text = prefix + str(bonus.value) + "% increased " + stat_name
				else: # PERCENT
					text = prefix + str(bonus.value) + "% more " + stat_name
			else:
				var prefix: String = "+" if bonus.value >= 0.0 else ""
				if bonus.mod_type == StatModifierData.ModType.FLAT:
					text = prefix + str(bonus.value) + " to " + stat_name
				else: # PERCENT
					text = prefix + str(bonus.value) + "% increased " + stat_name

			tooltip += text + "\n"

		_base_tooltip = tooltip.strip_edges()

		# Ajuster la taille en fonction du type
		if data.node_type == SkillNodeData.NodeType.KEYSTONE:
			custom_minimum_size = Vector2(64.0, 64.0)
			size = Vector2(64.0, 64.0)
		elif data.node_type == SkillNodeData.NodeType.NOTABLE:
			custom_minimum_size = Vector2(48.0, 48.0)
			size = Vector2(48.0, 48.0)
		else:
			custom_minimum_size = Vector2(32.0, 32.0)
			size = Vector2(32.0, 32.0)
	elif node_index == 0:
		_base_tooltip = "Origine de l'Arbre\nPoint de départ central (non remboursable)"

	# Centrer l'image (pivot) après avoir changé la taille
	pivot_offset = size / 2.0

	# Au départ, le nœud est verrouillé
	set_state(NodeState.LOCKED)
	queue_redraw()

func set_state(new_state: NodeState) -> void:
	current_state = new_state
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	rotation_degrees = 0.0

	match current_state:
		NodeState.LOCKED:
			# Sombre et un peu transparent
			modulate = _get_rest_modulate()
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			button_mask = 0
			scale = Vector2.ONE
		NodeState.AVAILABLE:
			# Couleurs normales, prêt à être cliqué (clic gauche)
			modulate = _get_rest_modulate()
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button_mask = MOUSE_BUTTON_MASK_LEFT
		NodeState.UNLOCKED:
			# Doré/brillant pour montrer qu'il est acquis (clic droit pour rembourser sauf origine)
			modulate = _get_rest_modulate()
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if node_index != 0 else Control.CURSOR_ARROW
			button_mask = 0

	_refresh_tooltip()
	queue_redraw()

func _get_rest_modulate() -> Color:
	match current_state:
		NodeState.LOCKED:
			return Color(0.5, 0.5, 0.5, 0.9)
		NodeState.AVAILABLE:
			return Color(1.0, 1.0, 1.0, 1.0)
		NodeState.UNLOCKED:
			return Color(1.2, 1.1, 0.5, 1.0)
	return Color.WHITE

func _refresh_tooltip() -> void:
	if _base_tooltip.is_empty():
		tooltip_text = ""
		return

	if current_state == NodeState.AVAILABLE:
		tooltip_text = _base_tooltip + "\n\n[Clic gauche : Allouer (1 pt)]"
	elif current_state == NodeState.UNLOCKED and node_index != 0:
		tooltip_text = _base_tooltip + "\n\n[Clic droit : Rembourser (1 pt de Regret)]"
	else:
		tooltip_text = _base_tooltip

func _draw() -> void:
	var center: Vector2 = size / 2.0
	# On prend un rayon légèrement plus petit pour laisser la place à la bordure
	var radius: float = (minf(size.x, size.y) / 2.0) - 1.0

	# Cercle de fond très sombre pour faire ressortir l'icône
	draw_circle(center, radius, Color(0.05, 0.05, 0.08, 0.95))

	# Bordure qui change de couleur selon l'état
	var border_color: Color = Color(0.2, 0.2, 0.2, 1.0) # Défaut / Locked
	if current_state == NodeState.AVAILABLE:
		border_color = Color(0.8, 0.8, 0.8, 1.0) # Blanc/Gris clair
	elif current_state == NodeState.UNLOCKED:
		border_color = Color(1.0, 0.8, 0.2, 1.0) # Doré

	draw_arc(center, radius, 0.0, TAU, 32, border_color, 2.0, true)

	# 3. Dessiner l'icône PAR-DESSUS le fond !
	if data != null and data.icon != null:
		# On dessine l'icône légèrement plus petite que le cercle pour voir la bordure
		# On garde les proportions de l'image
		var tex_size: Vector2 = data.icon.get_size()
		var target_size: Vector2 = size * 0.7 # L'icône prend 70% de la taille du bouton

		# On calcule le ratio pour ne pas déformer l'image (Keep Aspect Centered)
		var scale_factor: float = minf(target_size.x / tex_size.x, target_size.y / tex_size.y)
		var final_size: Vector2 = tex_size * scale_factor
		var icon_pos: Vector2 = center - (final_size / 2.0)

		draw_texture_rect(data.icon, Rect2(icon_pos, final_size), false)

func _pressed() -> void:
	if current_state == NodeState.AVAILABLE:
		node_clicked.emit(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if current_state == NodeState.UNLOCKED:
				accept_event()
				node_right_clicked.emit(self)

## Joue un petit tremblement rouge si le remboursement du nœud est refusé.
func play_reject_animation() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	rotation_degrees = 0.0
	var rest_color: Color = _get_rest_modulate()
	modulate = Color(1.85, 0.35, 0.35, 1.0)

	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "rotation_degrees", -10.0, 0.045)
	_feedback_tween.tween_property(self, "rotation_degrees", 10.0, 0.055)
	_feedback_tween.tween_property(self, "rotation_degrees", -6.0, 0.05)
	_feedback_tween.tween_property(self, "rotation_degrees", 6.0, 0.05)
	_feedback_tween.tween_property(self, "rotation_degrees", 0.0, 0.05)
	_feedback_tween.parallel().tween_property(self, "modulate", rest_color, 0.25)

# --- Effets Visuels ---
func _on_mouse_entered() -> void:
	_is_hovered = true
	if current_state != NodeState.LOCKED:
		if _hover_tween != null and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _on_button_down() -> void:
	if current_state != NodeState.LOCKED:
		if _hover_tween != null and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)

func _on_button_up() -> void:
	if current_state != NodeState.LOCKED:
		if _hover_tween != null and _hover_tween.is_valid():
			_hover_tween.kill()
		var target_scale: Vector2 = Vector2(1.1, 1.1) if _is_hovered else Vector2.ONE
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", target_scale, 0.05)

