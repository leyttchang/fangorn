class_name InventorySlot
extends Panel

var slot_index: int = -1
var current_item: ItemData = null

@onready var icon_rect: TextureRect = $Icon # Assure-toi que ton icône s'appelle bien "Icon"
@onready var highlight_rect: ReferenceRect = $NewItemHighlight if has_node("NewItemHighlight") else null

func _ready() -> void:
	# On s'abonne au survol de la souris
	mouse_entered.connect(_on_mouse_entered)

func update_slot(item: ItemData, quantity: int, index: int) -> void:
	slot_index = index
	current_item = item
	if item != null:
		icon_rect.texture = item.icon
		tooltip_text = " " # Active la détection de tooltip
		if highlight_rect:
			highlight_rect.visible = item.is_new_item
	else:
		icon_rect.texture = null
		tooltip_text = "" # Désactive le tooltip
		if highlight_rect:
			highlight_rect.visible = false

func _on_mouse_entered() -> void:
	# Dès qu'on passe la souris dessus, ce n'est plus "nouveau"
	if current_item != null and current_item.is_new_item:
		current_item.is_new_item = false
		if highlight_rect:
			highlight_rect.visible = false

# ==========================================
# TOOLTIP PERSONNALISÉ
# ==========================================
func _make_custom_tooltip(_for_text: String) -> Object:
	if current_item == null: return null
	
	var tooltip_scene = preload("res://ui/inventaire/item_tooltip.tscn")
	
	# Le conteneur principal qui va mettre les tooltips côte à côte
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	# 1. Préparer le tooltip de l'objet de l'inventaire
	var hovered_tooltip = tooltip_scene.instantiate()
	hovered_tooltip.set_item(current_item)
	
	# 2. Chercher si on a un objet équipé dans le même slot
	if current_item is EquipmentItem:
		var current_node = get_parent()
		var equip_comp = null
		while current_node != null:
			if current_node is InventoryUI:
				equip_comp = current_node.equipment_component
				break
			current_node = current_node.get_parent()
			
		if equip_comp != null:
			var slot_name = ItemData.ItemType.keys()[current_item.item_type]
			if equip_comp.equipped_items.has(slot_name) and equip_comp.equipped_items[slot_name] != null:
				var equipped_item = equip_comp.equipped_items[slot_name]
				# On ne l'affiche que si ce n'est pas EXACTEMENT le même objet (pour éviter un bug si on survole l'objet déjà équipé)
				if equipped_item != current_item:
					var equipped_tooltip = tooltip_scene.instantiate()
					equipped_tooltip.set_item(equipped_item)
					equipped_tooltip.set_equipped()
					
					# On ajoute le tooltip de l'équipement EN PREMIER (donc à gauche)
					hbox.add_child(equipped_tooltip)
	
	# 3. On ajoute le tooltip de l'inventaire EN SECOND (donc à droite)
	hbox.add_child(hovered_tooltip)
					
	return hbox

# ==========================================
# DÉBUT DU GLISSER (DRAG)
# ==========================================
func _get_drag_data(at_position: Vector2) -> Variant:
	# S'il n'y a pas d'objet dans cette case, on ne fait rien
	if current_item == null:
		return null 

	# 1. Création du fantôme visuel (l'icône qui suit la souris)
	var preview_texture = TextureRect.new()
	preview_texture.texture = current_item.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = size # Prend la même taille que la case
	preview_texture.modulate.a = 0.5 # Rend l'image semi-transparente
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * size # Centre l'image sur le curseur de la souris
	
	set_drag_preview(preview_control) # Dit à Godot d'afficher ce fantôme

	# 2. On emballe les données de l'objet pour le voyage
	var payload = {
		"type": "inventory_item",
		"item": current_item,
		"source_index": slot_index
	}
	return payload

# ==========================================
# CLIC DROIT : MENU CONTEXTUEL (JETER)
# ==========================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_item != null:
			_show_context_menu()

func _show_context_menu() -> void:
	# Créer un petit menu déroulant
	var popup = PopupMenu.new()
	popup.add_item("Throw (Delete)")
	popup.id_pressed.connect(_on_context_menu_id_pressed.bind(popup))
	
	# Très important : Si on clique à côté, ça ferme le menu et on le supprime
	popup.popup_hide.connect(popup.queue_free)
	
	add_child(popup)
	
	# Afficher le menu là où est la souris
	popup.popup(Rect2(get_global_mouse_position(), Vector2(120, 30)))

func _on_context_menu_id_pressed(id: int, popup: PopupMenu) -> void:
	if id == 0: # Si on a cliqué sur "Throw (Delete)"
		# On remonte l'arbre pour trouver l'InventoryUI et son composant
		var current_node = get_parent()
		var inv_comp = null
		while current_node != null:
			if current_node is InventoryUI: # "InventoryUI" est le nom de la classe
				inv_comp = current_node.inventory_component
				break
			current_node = current_node.get_parent()
			
		if inv_comp != null:
			# On supprime 999 quantités pour être sûr de vider toute la pile
			inv_comp.remove_item_at_slot(slot_index, 999)
