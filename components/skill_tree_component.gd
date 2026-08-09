class_name SkillTreeComponent
extends Node

signal skill_points_changed(new_points: int)

@export var stats_component: StatsComponent
@export var level_component: LevelComponent
@export var skill_tree_ui: Node # Référence vers le PassiveSkillTree (generator_test)

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

func _on_level_up(_new_level: int) -> void:
	available_skill_points += 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_passive_tree"):
		if skill_tree_ui:
			skill_tree_ui.visible = !skill_tree_ui.visible
			
			if skill_tree_ui.visible:
				# On affiche la souris pour pouvoir cliquer
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				
				# Centrer et réinitialiser le zoom de l'arbre à l'ouverture
				var canvas = skill_tree_ui.get_parent()
				if canvas is CanvasLayer:
					canvas.offset = Vector2(0, 0)
					canvas.scale = Vector2(1, 1)
					
				# Si vous voulez bloquer les clics in-game pendant l'ouverture de l'arbre
				get_viewport().set_input_as_handled()
			else:
				# On recache la souris quand on ferme l'arbre
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_tree_node_clicked(node_index: int, skill_data: SkillNodeData):
	# Si on a des points et qu'on ne l'a pas déjà débloqué
	if available_skill_points > 0 and not unlocked_nodes.has(node_index):
		available_skill_points -= 1
		unlocked_nodes.append(node_index)
		
		# On applique les stats
		if skill_data != null:
			_apply_stats(skill_data)
			
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
			if bonus.mod_type == 1: # PERCENT
				final_value = final_value / 100.0
				
			stats_component.add_modifier(bonus.stat_name, bonus.mod_type, final_value, source_id)
