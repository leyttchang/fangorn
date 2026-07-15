class_name InventoryComponent
extends Node

# Le signal qui préviendra l'UI qu'il faut se redessiner !
signal inventory_changed

# La taille de ton sac à dos
@export var max_slots: int = 20

# Notre tableau de cases. 
# Format d'une case : {"item": ItemData, "quantity": int}
var slots: Array[Dictionary] = []

func _ready() -> void:
	# Au démarrage, on crée 20 cases vides
	for i in range(max_slots):
		slots.append({"item": null, "quantity": 0})

# --- AJOUTER UN OBJET ---
# Renvoie le nombre d'objets qu'on n'a PAS pu ajouter (si le sac est plein)
func add_item(new_item: ItemData, amount: int = 1) -> int:
	var remaining = amount

	# 1. Si l'objet est empilable (ex: des flèches, du bois), on cherche d'abord une pile incomplète
	if new_item.is_stackable:
		for slot in slots:
			if slot["item"] != null and slot["item"].id == new_item.id:
				var space_left = slot["item"].max_stack - slot["quantity"]
				if space_left > 0:
					var to_add = min(space_left, remaining)
					slot["quantity"] += to_add
					remaining -= to_add
					
					if remaining == 0:
						inventory_changed.emit()
						return 0 # Tout a été rangé !

	# 2. On cherche des cases complètement vides pour le reste
	for slot in slots:
		if slot["item"] == null:
			slot["item"] = new_item
			
			if new_item.is_stackable:
				var to_add = min(new_item.max_stack, remaining)
				slot["quantity"] = to_add
				remaining -= to_add
			else:
				# Les armes (non-empilables) prennent une case entière par unité
				slot["quantity"] = 1
				remaining -= 1

			if remaining == 0:
				inventory_changed.emit()
				return 0

	# 3. Si on arrive ici, le sac est plein !
	# S'il reste des objets, le joueur les laissera par terre.
	if remaining != amount:
		# On a quand même réussi à ranger un peu, on prévient l'UI
		inventory_changed.emit()
		
	return remaining

# --- RETIRER UN OBJET ---
func remove_item_at_slot(slot_index: int, amount: int = 1) -> void:
	# Sécurité pour ne pas crasher si on demande une case qui n'existe pas
	if slot_index < 0 or slot_index >= max_slots:
		return
		
	var slot = slots[slot_index]
	
	if slot["item"] != null:
		slot["quantity"] -= amount
		
		# Si la case tombe à zéro (ou moins), on la vide complètement
		if slot["quantity"] <= 0:
			slot["item"] = null
			slot["quantity"] = 0
			
		inventory_changed.emit()
