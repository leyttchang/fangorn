class_name InventoryUI
extends CanvasLayer

@export var inventory_component: InventoryComponent 
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
		
		# Le drag and drop est géré tout seul dans InventorySlot et EquipmentSlot !
		slot_instance.update_slot(slot_data["item"], slot_data["quantity"], index)
		index += 1
