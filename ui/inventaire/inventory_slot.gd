class_name InventorySlot
extends Panel

var slot_index: int = -1
var current_item: ItemData = null

@onready var icon_rect: TextureRect = $Icon # Assure-toi que ton icône s'appelle bien "Icon"

func update_slot(item: ItemData, quantity: int, index: int) -> void:
	slot_index = index
	current_item = item
	if item != null:
		icon_rect.texture = item.icon
	else:
		icon_rect.texture = null

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
