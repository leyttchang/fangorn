class_name SkillTreeComponent
extends Node

signal skill_points_changed(new_points: int)

@export var stats_component: StatsComponent
@export var level_component: LevelComponent
@export var skill_tree_ui: Node # Référence vers le PassiveSkillTree (generator_test)
@export var points_label: Label # NOUVEAU : Référence vers le Label textuel

@export var available_skill_points: int = 5 :
	set(val):
		available_skill_points = val
		skill_points_changed.emit(val)

@export var tree_seed: int = 0
@export var unlocked_nodes: Array[int] = []

func _ready():
	if tree_seed == 0:
		randomize()
		tree_seed = randi()
		
	if skill_tree_ui:
		# Par défaut, on cache l'arbre au lancement du jeu
		skill_tree_ui.hide()
		skill_tree_ui.tree_seed = tree_seed
		# On écoute quand le joueur veut acheter un point
		skill_tree_ui.tree_node_clicked.connect(_on_tree_node_clicked)

	if level_component:
		level_component.level_up.connect(_on_level_up)
		
	# Mise à jour initiale du label
	skill_points_changed.connect(_update_points_label)
	_update_points_label(available_skill_points)

func _update_points_label(points: int) -> void:
	if points_label != null:
		points_label.text = "Points de compétence : " + str(points)

func _on_level_up(_new_level: int) -> void:
	available_skill_points += 1

func open_tree() -> void:
	if skill_tree_ui:
		skill_tree_ui.visible = true
		# Centrer et réinitialiser le zoom de l'arbre à l'ouverture
		var canvas = skill_tree_ui.get_parent()
		if canvas is CanvasLayer:
			canvas.offset = Vector2(0, 0)
			canvas.scale = Vector2(1, 1)
			
	if points_label:
		points_label.visible = true

func close_tree() -> void:
	if skill_tree_ui:
		skill_tree_ui.visible = false
		
	if points_label:
		points_label.visible = false

func _on_tree_node_clicked(node_index: int, skill_data: SkillNodeData):
	# Si on a des points et qu'on ne l'a pas déjà débloqué
	if available_skill_points > 0 and not unlocked_nodes.has(node_index):
		available_skill_points -= 1
		unlocked_nodes.append(node_index)
		
		# On applique les stats ou la mécanique
		if skill_data != null:
			_apply_stats(skill_data)
			if skill_data.node_type == SkillNodeData.NodeType.KEYSTONE:
				_apply_keystone(skill_data)
			
		# On dit à l'interface de s'allumer et de débloquer les voisins
		skill_tree_ui.unlock_node(node_index)
		
func _apply_stats(skill_data: SkillNodeData):
	if stats_component == null:
		push_warning("SkillTreeComponent: Pas de StatsComponent assigné pour recevoir les bonus !")
		return
		
	for bonus in skill_data.stats_bonuses:
		if bonus != null:
			# source_id unique pour pouvoir l'enlever un jour si on ajoute un système de respect
			var source_id = "skill_tree_" + skill_data.node_id
			
			var final_value = bonus.value
			var is_percent_stat = bonus.stat_name in GameData.PERCENT_STATS
			
			if bonus.mod_type == StatModifierData.ModType.PERCENT or is_percent_stat:
				final_value = final_value / 100.0
				
			stats_component.add_modifier(bonus.stat_name, bonus.mod_type, final_value, source_id)

func _apply_keystone(skill_data: SkillNodeData):
	# On cherche le script en utilisant l'id du node (ex: "double_jump")
	var keystone_path = "res://passive_skill_tree/ressource_node/Keystone/" + skill_data.node_id + ".gd"
	
	if ResourceLoader.exists(keystone_path):
		var script = load(keystone_path)
		var keystone_node = Node.new()
		keystone_node.set_script(script)
		keystone_node.name = "Keystone_" + skill_data.node_id
		
		# On récupère le dossier KeystoneModifiers (que vous avez déjà créé dans la scène)
		var player = get_parent()
		var modifiers_container = player.get_node("KeystoneModifiers")
			
		# On attache le script ! Il va s'exécuter tout seul.
		modifiers_container.add_child(keystone_node)
		print("Keystone activée : ", skill_data.node_name)
	else:
		push_warning("Script de keystone introuvable : " + keystone_path)
