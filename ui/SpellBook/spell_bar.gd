class_name SpellBarUI
extends CanvasLayer

# Référence au script logique (à glisser dans l'inspecteur)
@export var skill_bar: SkillBarComponent

# Chemin exact vers la grille contenant les slots
@onready var grid: Control = $MainPanel/inventaire/inv_grid

func _ready() -> void:
	if skill_bar == null:
		push_error("SpellBarUI : Le composant SkillBarComponent n'est pas assigné dans l'inspecteur.")
		return
	skill_bar.spells_updated.connect(update_all_slots)
		
	# Initialisation de l'affichage au lancement
	update_all_slots()
func _process(_delta: float) -> void:
	if skill_bar == null:
		return

	var slot_nodes = grid.get_children()
	
	for i in range(slot_nodes.size()):
		var slot_key: String = "slot_" + str(i + 1)
		var slot_node: Node = slot_nodes[i]
		
		# On récupère les deux nœuds visuels
		var overlay: TextureProgressBar = slot_node.get_node_or_null("CooldownOverlay")
		var cd_label: Label = slot_node.get_node_or_null("cd")
		
		if overlay == null:
			continue
			
		if skill_bar.slots.has(slot_key) and skill_bar.slots[slot_key] != null:
			var ability_name = skill_bar.slots[slot_key].ability_name
			
			if skill_bar.cooldown_timers.has(ability_name):
				var timer: Timer = skill_bar.cooldown_timers[ability_name]
				
				if is_instance_valid(timer):
					# 1. On met à jour l'ombre
					overlay.visible = true
					overlay.max_value = timer.wait_time
					overlay.value = timer.time_left
					
					# 2. On met à jour le texte
					if cd_label != null:
						cd_label.visible = true
						# "ceili" permet d'arrondir à l'entier supérieur (ex: 2.1 affiche 3)
						# pour un affichage propre comme dans les RPG
						cd_label.text = "%.1f" % timer.time_left
				else:
					overlay.visible = false
					if cd_label != null: cd_label.visible = false
			else:
				overlay.visible = false
				if cd_label != null: cd_label.visible = false
		else:
			overlay.visible = false
			if cd_label != null: cd_label.visible = false
func update_all_slots() -> void:
	var slot_nodes = grid.get_children()
	
	for i in range(slot_nodes.size()):
		var slot_key: String = "slot_" + str(i + 1)
		var slot_node: Node = slot_nodes[i]
		
		if not skill_bar.slots.has(slot_key):
			continue
			
		var ability: AbilityData = skill_bar.slots[slot_key]
		_update_single_slot(slot_node, ability)

func _update_single_slot(slot_node: Node, ability: AbilityData) -> void:
	# On récupère le nœud image enfant du slot
	var icon_rect: TextureRect = slot_node.get_node_or_null("Icon")
	
	if icon_rect == null:
		push_warning("SpellBarUI : Le nœud TextureRect 'Icon' est introuvable dans " + slot_node.name)
		return
		
	# Application des données
	if ability != null and ability.icon != null:
		icon_rect.texture = ability.icon
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false
