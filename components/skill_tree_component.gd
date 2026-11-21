class_name SkillTreeComponent
extends Node

const ROOT_NODE_INDEX: int = 0

signal skill_points_changed(new_points: int)
signal refund_points_changed(new_points: int)
signal node_unlocked(node_index: int, skill_data: SkillNodeData)
signal node_refunded(node_index: int, skill_data: SkillNodeData)

@export var stats_component: StatsComponent
@export var level_component: LevelComponent
@export var skill_tree_ui: Node # Référence vers le PassiveSkillTree (generator_test)
@export var points_label: Label # Référence vers le Label textuel des points

@export var available_skill_points: int = 5 :
	set(val):
		available_skill_points = maxi(0, val)
		skill_points_changed.emit(available_skill_points)
		_update_points_label()

@export var available_refund_points: int = 0 :
	set(val):
		available_refund_points = maxi(0, val)
		refund_points_changed.emit(available_refund_points)
		_update_points_label()

## Nombre de premiers level-ups accordant chacun +1 point de remboursement (Regret) gratuit.
@export var max_free_refund_level_ups: int = 10

@export var tree_seed: int = 0
@export var unlocked_nodes: Array[int] = []

var _refund_level_ups_granted: int = 0
var _unlocked_skill_data: Dictionary = {}

var _hint_label: Label = null
var _feedback_label: Label = null
var _feedback_tween: Tween = null

func _ready() -> void:
	if tree_seed == 0:
		randomize()
		tree_seed = randi()

	if skill_tree_ui != null:
		# Par défaut, on cache l'arbre au lancement du jeu
		var tree_control: Control = skill_tree_ui as Control
		if tree_control != null:
			tree_control.hide()
		if "tree_seed" in skill_tree_ui:
			skill_tree_ui.set("tree_seed", tree_seed)
		# Écouter l'achat (clic gauche) et le remboursement (clic droit)
		if skill_tree_ui.has_signal("tree_node_clicked"):
			skill_tree_ui.connect("tree_node_clicked", _on_tree_node_clicked)
		if skill_tree_ui.has_signal("tree_node_right_clicked"):
			skill_tree_ui.connect("tree_node_right_clicked", _on_tree_node_right_clicked)

	if level_component != null:
		level_component.level_up.connect(_on_level_up)

	_setup_extra_ui()
	if points_label != null:
		points_label.visible = false
	_update_points_label()

func _setup_extra_ui() -> void:
	if points_label == null or points_label.get_parent() == null:
		return

	var ui_parent: Node = points_label.get_parent()

	_hint_label = Label.new()
	_hint_label.name = "RefundHintLabel"
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.offset_left = -320.0
	_hint_label.offset_right = 320.0
	_hint_label.offset_top = 28.0
	_hint_label.offset_bottom = 50.0
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.text = "Clic gauche : Allouer (1 pt)   •   Clic droit sur un nœud : Rembourser (1 pt)"

	var hint_settings: LabelSettings = LabelSettings.new()
	hint_settings.font_size = 14
	hint_settings.font_color = Color(0.88, 0.88, 0.92, 0.92)
	hint_settings.outline_size = 4
	hint_settings.outline_color = Color(0.05, 0.05, 0.08, 0.95)
	_hint_label.label_settings = hint_settings
	_hint_label.visible = false
	if ui_parent == get_parent():
		ui_parent.add_child.call_deferred(_hint_label)
	else:
		ui_parent.add_child(_hint_label)

	_feedback_label = Label.new()
	_feedback_label.name = "RefundFeedbackLabel"
	_feedback_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_feedback_label.anchor_left = 0.5
	_feedback_label.anchor_right = 0.5
	_feedback_label.offset_left = -380.0
	_feedback_label.offset_right = 380.0
	_feedback_label.offset_top = 52.0
	_feedback_label.offset_bottom = 78.0
	_feedback_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var feedback_settings: LabelSettings = LabelSettings.new()
	feedback_settings.font_size = 15
	feedback_settings.font_color = Color(1.0, 0.42, 0.35, 1.0)
	feedback_settings.outline_size = 5
	feedback_settings.outline_color = Color(0.05, 0.05, 0.08, 0.95)
	_feedback_label.label_settings = feedback_settings
	_feedback_label.visible = false
	_feedback_label.modulate.a = 0.0
	if ui_parent == get_parent():
		ui_parent.add_child.call_deferred(_feedback_label)
	else:
		ui_parent.add_child(_feedback_label)

func _update_points_label(_unused_points: int = -1) -> void:
	if points_label != null:
		points_label.text = "Points de compétence : %d   |   Points de Regret : %d" % [
			available_skill_points,
			available_refund_points
		]

func _show_feedback(message: String, is_error: bool = true) -> void:
	if _feedback_label == null:
		return

	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	_feedback_label.text = message
	if _feedback_label.label_settings != null:
		_feedback_label.label_settings.font_color = (
			Color(1.0, 0.42, 0.35, 1.0) if is_error else Color(0.6, 0.95, 0.65, 1.0)
		)

	var tree_control: Control = skill_tree_ui as Control
	var is_tree_open: bool = tree_control != null and tree_control.visible
	_feedback_label.visible = is_tree_open
	_feedback_label.modulate.a = 1.0

	if is_inside_tree() and is_tree_open:
		_feedback_tween = create_tween()
		_feedback_tween.tween_interval(1.8)
		_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.45)

func add_refund_points(amount: int) -> void:
	if amount <= 0:
		return
	available_refund_points += amount

func _on_level_up(new_level: int) -> void:
	available_skill_points += 1

	# Le joueur commence au niveau 1 : les 10 premiers level-ups (niveaux 2 à 11 inclus)
	# accordent chacun +1 point de compétence ET +1 point de remboursement (Regret).
	var within_initial_levels: bool = (new_level <= 0) or (new_level <= 1 + max_free_refund_level_ups)
	if _refund_level_ups_granted < max_free_refund_level_ups and within_initial_levels:
		_refund_level_ups_granted += 1
		available_refund_points += 1

func open_tree() -> void:
	var tree_control: Control = skill_tree_ui as Control
	if tree_control != null:
		tree_control.visible = true
		# Centrer et réinitialiser le zoom de l'arbre à l'ouverture
		var canvas: CanvasLayer = tree_control.get_parent() as CanvasLayer
		if canvas != null:
			canvas.offset = Vector2.ZERO
			canvas.scale = Vector2.ONE

	if points_label != null:
		points_label.visible = true
	if _hint_label != null:
		_hint_label.visible = true
	if _feedback_label != null:
		_feedback_label.visible = false
		_feedback_label.modulate.a = 0.0

func close_tree() -> void:
	var tree_control: Control = skill_tree_ui as Control
	if tree_control != null:
		tree_control.visible = false

	if points_label != null:
		points_label.visible = false
	if _hint_label != null:
		_hint_label.visible = false
	if _feedback_label != null:
		if _feedback_tween != null and _feedback_tween.is_valid():
			_feedback_tween.kill()
		_feedback_label.visible = false
		_feedback_label.modulate.a = 0.0

func _on_tree_node_clicked(node_index: int, skill_data: SkillNodeData) -> void:
	# Si on a des points et qu'on ne l'a pas déjà débloqué
	if available_skill_points > 0 and not unlocked_nodes.has(node_index):
		available_skill_points -= 1
		unlocked_nodes.append(node_index)
		_unlocked_skill_data[node_index] = skill_data

		# On applique les stats ou la mécanique
		if skill_data != null:
			_apply_stats(node_index, skill_data)
			if skill_data.node_type == SkillNodeData.NodeType.KEYSTONE:
				_apply_keystone(node_index, skill_data)

		# On dit à l'interface de s'allumer et de débloquer les voisins
		if skill_tree_ui != null and skill_tree_ui.has_method("unlock_node"):
			skill_tree_ui.call("unlock_node", node_index)

		node_unlocked.emit(node_index, skill_data)
	elif available_skill_points <= 0 and not unlocked_nodes.has(node_index):
		_show_feedback("Aucun point de compétence disponible !", true)
		if skill_tree_ui != null and skill_tree_ui.has_method("play_reject_feedback"):
			skill_tree_ui.call("play_reject_feedback", node_index)

func _on_tree_node_right_clicked(node_index: int, skill_data: SkillNodeData) -> void:
	try_refund_node(node_index, skill_data)

## Tente de rembourser un nœud alloué selon les règles de Path of Exile :
## 1) Avoir au moins 1 point de Regret (`available_refund_points > 0`)
## 2) Ne pas être le nœud central de départ (`ROOT_NODE_INDEX == 0`)
## 3) Ne pas déconnecter d'autres nœuds alloués de la racine de départ
func try_refund_node(node_index: int, skill_data: SkillNodeData = null) -> bool:
	if node_index == ROOT_NODE_INDEX:
		_show_feedback("Le point de départ central ne peut pas être remboursé.", true)
		if skill_tree_ui != null and skill_tree_ui.has_method("play_reject_feedback"):
			skill_tree_ui.call("play_reject_feedback", node_index)
		return false

	if not unlocked_nodes.has(node_index):
		return false

	if available_refund_points <= 0:
		_show_feedback("Aucun point de Regret disponible pour rembourser ce nœud !", true)
		if skill_tree_ui != null and skill_tree_ui.has_method("play_reject_feedback"):
			skill_tree_ui.call("play_reject_feedback", node_index)
		return false

	if skill_tree_ui != null and skill_tree_ui.has_method("can_refund_node"):
		var stays_connected: bool = bool(skill_tree_ui.call("can_refund_node", node_index, unlocked_nodes))
		if not stays_connected:
			_show_feedback("Impossible de rembourser : d'autres nœuds alloués dépendent de ce chemin !", true)
			if skill_tree_ui.has_method("play_reject_feedback"):
				skill_tree_ui.call("play_reject_feedback", node_index)
			return false

	var resolved_data: SkillNodeData = skill_data
	if resolved_data == null and _unlocked_skill_data.has(node_index):
		resolved_data = _unlocked_skill_data[node_index] as SkillNodeData
	if resolved_data == null and skill_tree_ui != null and skill_tree_ui.has_method("get_node_skill_data"):
		resolved_data = skill_tree_ui.call("get_node_skill_data", node_index) as SkillNodeData

	# Consommer 1 point de Regret et restituer 1 point de compétence
	available_refund_points -= 1
	available_skill_points += 1
	unlocked_nodes.erase(node_index)
	_unlocked_skill_data.erase(node_index)

	# Retirer uniquement les bonus associés à CE node_index précis
	_remove_stats(node_index)
	if resolved_data != null and resolved_data.node_type == SkillNodeData.NodeType.KEYSTONE:
		_remove_keystone(node_index, resolved_data)

	# Mettre à jour l'état visuel du nœud, des voisins et des lignes de connexion
	if skill_tree_ui != null and skill_tree_ui.has_method("refund_node"):
		skill_tree_ui.call("refund_node", node_index)

	_show_feedback("Nœud remboursé (+1 point de compétence)", false)
	node_refunded.emit(node_index, resolved_data)
	return true

func _get_node_source_id(node_index: int) -> String:
	return "skill_tree_node_%d" % node_index

func _get_keystone_instance_name(node_index: int, skill_data: SkillNodeData) -> String:
	return "Keystone_%d_%s" % [node_index, skill_data.node_id]

func _apply_stats(node_index: int, skill_data: SkillNodeData) -> void:
	if stats_component == null:
		push_warning("SkillTreeComponent: Pas de StatsComponent assigné pour recevoir les bonus !")
		return

	var source_id: String = _get_node_source_id(node_index)
	for bonus: StatModifierData in skill_data.stats_bonuses:
		if bonus != null:
			var final_value: float = bonus.value
			var is_percent_stat: bool = bonus.stat_name in GameData.PERCENT_STATS

			if bonus.mod_type == StatModifierData.ModType.PERCENT or is_percent_stat:
				final_value = final_value / 100.0

			stats_component.add_modifier(bonus.stat_name, bonus.mod_type, final_value, source_id)

func _remove_stats(node_index: int) -> void:
	if stats_component == null:
		return

	var source_id: String = _get_node_source_id(node_index)
	stats_component.remove_modifier_by_source(source_id)

func _apply_keystone(node_index: int, skill_data: SkillNodeData) -> void:
	# On cherche le script en utilisant l'id du node (ex: "double_jump")
	var keystone_path: String = "res://passive_skill_tree/ressource_node/Keystone/" + skill_data.node_id + ".gd"

	if ResourceLoader.exists(keystone_path):
		var script: Script = load(keystone_path) as Script
		if script == null:
			push_warning("Script de keystone invalide : " + keystone_path)
			return

		var keystone_node: Node = Node.new()
		keystone_node.set_script(script)
		keystone_node.name = _get_keystone_instance_name(node_index, skill_data)

		# On récupère le dossier KeystoneModifiers sur le joueur
		var player: Node = get_parent()
		if player == null:
			keystone_node.free()
			return

		var modifiers_container: Node = player.get_node_or_null("KeystoneModifiers")
		if modifiers_container == null:
			push_warning("SkillTreeComponent: Conteneur 'KeystoneModifiers' introuvable sur le joueur !")
			keystone_node.free()
			return

		# On attache le script ! Il va s'exécuter tout seul.
		modifiers_container.add_child(keystone_node)
		print("Keystone activée : ", skill_data.node_name)
	else:
		push_warning("Script de keystone introuvable : " + keystone_path)

func _remove_keystone(node_index: int, skill_data: SkillNodeData) -> void:
	var player: Node = get_parent()
	if player == null:
		return

	var modifiers_container: Node = player.get_node_or_null("KeystoneModifiers")
	if modifiers_container == null:
		return

	var target_name: String = _get_keystone_instance_name(node_index, skill_data)
	var keystone_node: Node = modifiers_container.get_node_or_null(NodePath(target_name))
	if keystone_node == null:
		keystone_node = modifiers_container.get_node_or_null(NodePath("Keystone_" + skill_data.node_id))

	if keystone_node != null:
		# Retrait immédiat de l'arbre pour exécuter _exit_tree() de manière synchrone
		modifiers_container.remove_child(keystone_node)
		keystone_node.queue_free()
		print("Keystone désactivée : ", skill_data.node_name)

