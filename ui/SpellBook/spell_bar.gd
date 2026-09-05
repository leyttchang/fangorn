class_name SpellBarUI
extends Control

# Référence au script logique (à glisser dans l'inspecteur)
@export var skill_bar: SkillBarComponent

# Chemin exact vers la grille contenant les slots
@onready var grid: Control = %inv_grid

func _ready() -> void:
	if skill_bar == null:
		# On cherche LE JOUEUR auquel appartient cette UI, pas le premier de la scène !
		var p = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				skill_bar = p.get_node_or_null("SkillBarComponent")
				break
			p = p.owner if p.owner != null else p.get_parent()
			
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
	
	var is_spell_selected = skill_bar.current_state in [SkillBarComponent.State.SELECTED, SkillBarComponent.State.CASTING]
	var selected_action = skill_bar.casting_action
	
	for i in range(slot_nodes.size()):
		var slot_key: String = "slot_" + str(i + 1)
		var slot_node: Node = slot_nodes[i]
		
		# --- GESTION DE L'OUTLINE DE SÉLECTION ---
		var outline = slot_node.get_node_or_null("SelectionOutline")
		if outline == null:
			outline = ReferenceRect.new()
			outline.name = "SelectionOutline"
			outline.border_color = Color.WHITE
			outline.border_width = 2.0
			outline.editor_only = false
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outline.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot_node.add_child(outline)
			
		outline.visible = (is_spell_selected and selected_action == slot_key)
		
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
		
		# --- INJECTION DES DONNEES POUR LE DRAG AND DROP ---
		slot_node.set("slot_name", slot_key)
		slot_node.set("skill_bar", skill_bar)
		
		# Mise à jour du Label de touche (Hotkey)
		var hotkey_label: Label = slot_node.get_node_or_null("Hotkey")
		if hotkey_label == null:
			hotkey_label = slot_node.get_node_or_null("hotkey")
			
		if hotkey_label != null:
			var key_text = _get_action_key_text(slot_key, i + 1)
			hotkey_label.text = key_text
			hotkey_label.visible = true
		
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
	slot_node.set("ability", ability)
	if ability != null and ability.icon != null:
		icon_rect.texture = ability.icon
		icon_rect.visible = true
		slot_node.set("tooltip_text", " ")
	else:
		icon_rect.texture = null
		icon_rect.visible = false
		slot_node.set("tooltip_text", "")

func _get_action_key_text(action_name: String, fallback_number: int) -> String:
	if InputMap.has_action(action_name):
		var events = InputMap.action_get_events(action_name)
		for event in events:
			if event is InputEventKey:
				var text = event.as_text_physical_keycode()
				if text == "":
					text = OS.get_keycode_string(event.keycode)
				text = text.replace("Physical", "").replace("Key", "").strip_edges()
				if text != "":
					return text
			elif event is InputEventMouseButton:
				return "M" + str(event.button_index)
	return str(fallback_number)
