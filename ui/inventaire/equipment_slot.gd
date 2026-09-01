class_name EquipmentSlot
extends Panel

@export var slot_name: String = "main_hand" 
@export var equipment_component: EquipmentComponent
@export var inventory_component: InventoryComponent # <-- C'EST LUI LE COUPABLE SI ÇA DUPLIQUE

@onready var icon_rect: TextureRect = $Icon

var glow_outline: ReferenceRect
var glow_tween: Tween

func _ready() -> void:
	# Création d'une bordure de surbrillance dédiée au drag and drop
	glow_outline = ReferenceRect.new()
	glow_outline.border_color = Color(1.0, 0.9, 0.5, 1.0)
	glow_outline.border_width = 3.0
	glow_outline.editor_only = false
	glow_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_outline.visible = false
	add_child(glow_outline)

	# Auto-découverte des composants si on a oublié de les assigner dans l'éditeur
	if equipment_component == null or inventory_component == null:
		var current_node = get_parent()
		while current_node != null:
			if current_node is InventoryUI:
				if equipment_component == null:
					equipment_component = current_node.equipment_component
				if inventory_component == null:
					inventory_component = current_node.inventory_component
				break
			current_node = current_node.get_parent()

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
	tooltip.set_equipped()
	
	# Wrappé dans un HBoxContainer pour forcer Godot à calculer la hauteur correctement (bug Godot 4)
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(tooltip)
	
	return hbox

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "inventory_item":
		var item: ItemData = data["item"]
		var item_type_string = ItemData.ItemType.keys()[item.item_type]
		
		if item_type_string == slot_name:
			return true
		
		# Autoriser les armes principales dans le 2ème slot d'arme
		if slot_name == "second_weapon" and item_type_string == "main_hand":
			return true
			
	return false 

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item_to_equip: ItemData = data["item"]
	var source_index: int = data["source_index"]
	var source_inventory: InventoryComponent = data.get("source_inventory")
	var quantity: int = data.get("quantity", 1)
	
	if source_inventory == null:
		# Fallback au cas où
		source_inventory = inventory_component
		
	# 1. ON RETIRE L'OBJET DE L'INVENTAIRE EN PREMIER (On libère la case)
	source_inventory.remove_item_at_slot(source_index, quantity)
	
	# 2. On équipe la nouvelle arme. 
	# La magie opère ici : si le joueur tient déjà une épée, ton 'EquipmentComponent' 
	# va la déséquiper et la ranger LUI-MÊME dans la case qu'on vient juste de vider 
	# (il la mettra dans l'inventaire du joueur grâce au code de EquipmentComponent).
	var success = equipment_component.equip_item(item_to_equip, slot_name)
	
	if not success:
		# Sécurité : Si l'équipement échoue, on remet l'objet là d'où il vient !
		source_inventory.set_item_at_slot(source_index, item_to_equip, quantity)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var drag_data = get_viewport().gui_get_drag_data()
		if _can_drop_data(Vector2.ZERO, drag_data):
			_start_glow()
	elif what == NOTIFICATION_DRAG_END:
		_stop_glow()

func _start_glow() -> void:
	if glow_outline == null: return
	glow_outline.visible = true
	glow_outline.modulate.a = 0.0
	
	if glow_tween:
		glow_tween.kill()
		
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow_outline, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_outline, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _stop_glow() -> void:
	if glow_tween:
		glow_tween.kill()
		glow_tween = null
	if glow_outline:
		glow_outline.visible = false
