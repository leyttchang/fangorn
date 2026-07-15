class_name InventoryUI
extends CanvasLayer

@export var inventory_component: InventoryComponent 
# NOUVEAU : On a besoin du composant d'équipement du joueur
@export var equipment_component: EquipmentComponent 
@export var slot_scene: PackedScene 

@onready var inv_grid: GridContainer = %inv_grid

func _ready() -> void:
	visible = false
	if inventory_component != null:
		inventory_component.inventory_changed.connect(update_ui)
		update_ui()
	else:
		push_error("InventoryUI : Il manque le InventoryComponent !")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_ui() -> void:
	for child in inv_grid.get_children():
		child.queue_free()
		
	var index = 0
	for slot_data in inventory_component.slots:
		var slot_instance = slot_scene.instantiate() as InventorySlot
		inv_grid.add_child(slot_instance)
		
		# On écoute le signal du clic droit sur cette nouvelle case
		slot_instance.slot_right_clicked.connect(_on_slot_right_clicked)
		
		# On met à jour l'image en lui passant son index
		slot_instance.update_slot(slot_data["item"], slot_data["quantity"], index)
		index += 1

# --- LA MAGIE DU CLIC DROIT ---
func _on_slot_right_clicked(slot_index: int) -> void:
	# 1. On retrouve quel objet était dans cette case
	var item = inventory_component.slots[slot_index]["item"]
	
	if equipment_component != null and item is WeaponItem:
		# 2. On l'équipe dans la main droite
		var success = equipment_component.equip_item(item, "main_hand")
		
		# 3. Si l'équipement a réussi, on le retire du sac à dos
		if success:
			inventory_component.remove_item_at_slot(slot_index, 1)
