class_name InventorySlot
extends Panel

# Le signal qui va crier à l'UI : "On m'a fait un clic droit !"
signal slot_right_clicked(slot_index: int)

@onready var icon_rect: TextureRect = $Icon
@onready var quantity_label: Label = $Quantity

# La mémoire de la case
var my_index: int = -1
var current_item: ItemData = null

# On a ajouté "index" dans les paramètres
func update_slot(item: ItemData, quantity: int, index: int) -> void:
	current_item = item
	my_index = index
	
	if item == null:
		icon_rect.texture = null
		quantity_label.text = ""
	else:
		icon_rect.texture = item.icon
		if item.is_stackable and quantity > 1:
			quantity_label.text = str(quantity)
		else:
			quantity_label.text = ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Clic GAUCHE sur la case ", my_index)
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Si la case n'est pas vide, on envoie le signal avec notre numéro !
			if current_item != null:
				slot_right_clicked.emit(my_index)
