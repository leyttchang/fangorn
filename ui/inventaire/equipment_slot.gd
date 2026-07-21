class_name EquipmentSlot
extends Panel

@export var slot_name: String = "main_hand" 
@export var equipment_component: EquipmentComponent
@export var inventory_component: InventoryComponent # <-- C'EST LUI LE COUPABLE SI ÇA DUPLIQUE

@onready var icon_rect: TextureRect = $Icon

func _ready() -> void:
	if equipment_component != null:
		equipment_component.equipment_changed.connect(_on_equipment_changed)
		var starting_item = equipment_component.equipped_items.get(slot_name)
		_update_visual(starting_item)
	else:
		push_warning("EquipmentSlot : Il manque le EquipmentComponent sur " + slot_name)
		
	# Nouvelle sécurité au lancement :
	if inventory_component == null:
		push_warning("⚠️ ATTENTION : inventory_component manquant sur le slot " + slot_name + " ! La suppression d'objet va bugger.")

func _on_equipment_changed(changed_slot_name: String, item: ItemData) -> void:
	if changed_slot_name == slot_name:
		_update_visual(item)

var current_item: ItemData = null

func _update_visual(item: ItemData) -> void:
	current_item = item
	if item == null:
		icon_rect.texture = null
		tooltip_text = "" # Désactive le tooltip
	else:
		icon_rect.texture = item.icon
		tooltip_text = " " # Active le tooltip

# ==========================================
# TOOLTIP PERSONNALISÉ
# ==========================================
func _make_custom_tooltip(_for_text: String) -> Object:
	if current_item == null: return null
	var tooltip_scene = preload("res://ui/inventaire/item_tooltip.tscn")
	var tooltip = tooltip_scene.instantiate()
	tooltip.set_item(current_item)
	return tooltip

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "inventory_item":
		var item: ItemData = data["item"]
		var item_type_string = ItemData.ItemType.keys()[item.item_type]
		
		if item_type_string == slot_name:
			return true
			
	return false 

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item_to_equip: ItemData = data["item"]
	var source_index: int = data["source_index"]
	
	# 1. ON RETIRE L'OBJET DE L'INVENTAIRE EN PREMIER (On libère la case)
	inventory_component.remove_item_at_slot(source_index, 1)
	
	# 2. On équipe la nouvelle arme. 
	# La magie opère ici : si le joueur tient déjà une épée, ton 'EquipmentComponent' 
	# va la déséquiper et la ranger LUI-MÊME dans la case qu'on vient juste de vider !
	var success = equipment_component.equip_item(item_to_equip, slot_name)
	
	if not success:
		# Sécurité : Si l'équipement échoue, on remet l'objet dans l'inventaire
		inventory_component.add_item(item_to_equip, 1)
