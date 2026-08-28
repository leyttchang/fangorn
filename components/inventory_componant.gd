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

# --- FORCER UN OBJET DANS UNE CASE (Utile pour le drag & drop) ---
func set_item_at_slot(slot_index: int, item: ItemData, quantity: int) -> void:
	if slot_index < 0 or slot_index >= max_slots:
		return
	slots[slot_index]["item"] = item
	slots[slot_index]["quantity"] = quantity
	inventory_changed.emit()

# --- VÉRIFIER SI L'INVENTAIRE EST VIDE ---
func is_empty() -> bool:
	for slot in slots:
		if slot["item"] != null:
			return false
	return true

# --- COMPRESSION POUR LE RESEAU ---
func pack_item(item: ItemData) -> Dictionary:
	var dict = {
		"base_path": item.original_base_path if item.original_base_path != "" else item.resource_path,
		"rarity": item.rarity,
		"ilvl": item.ilvl
	}
	if item is EquipmentItem:
		dict["is_equip"] = true
		dict["stats"] = item.stat_bonuses
		dict["innate"] = item.innate_stats
		dict["affix"] = item.affix_stats
	else:
		dict["is_equip"] = false
	return dict

func unpack_item(dict: Dictionary) -> ItemData:
	if not dict.has("base_path") or dict["base_path"] == "": return null
	var base = load(dict["base_path"])
	if base == null: return null
	
	var new_item = base.duplicate(true)
	new_item.original_base_path = dict["base_path"]
	new_item.rarity = dict["rarity"]
	new_item.ilvl = dict["ilvl"]
	
	if dict.get("is_equip", false) and new_item is EquipmentItem:
		new_item.stat_bonuses = dict["stats"]
		new_item.innate_stats = dict["innate"]
		new_item.affix_stats = dict["affix"]
	
	return new_item

@rpc("any_peer", "call_local", "reliable")
func _rpc_spawn_bag(item_dict: Dictionary, amount: int) -> void:
	if not multiplayer.is_server(): return
	
	var item = unpack_item(item_dict)
	if item == null:
		print("[DROP ERREUR] L'objet n'a pas pu etre decompresse ! base_path manquant : ", item_dict)
		return
	
	var bag_scene = load("res://objet/item_bag/item_bag.tscn")
	if bag_scene != null:
		var bag = bag_scene.instantiate()
		bag.item_data = item
		bag.item_amount = amount
		
		# Trouver le joueur qui a demande le drop
		var player = get_parent()
		if player is CharacterBody3D:
			# L'ajouter dans NetworkObjects
			var network_objects = null
			var root = player.get_parent()
			while root != null:
				if root.has_node("NetworkObjects"):
					network_objects = root.get_node("NetworkObjects")
					break
				root = root.get_parent()
			
			if network_objects != null:
				network_objects.add_child(bag, true)
			else:
				player.get_parent().add_child(bag, true)
			
			# Ensuite on le positionne devant le joueur
			var pos = player.global_position + Vector3(0, 1.5, 0)
			bag.global_position = pos
			var forward = -player.global_transform.basis.z.normalized()
			bag.linear_velocity = forward * 5.0 + Vector3(0, 2.0, 0)

# --- RECEPTION D'UN OBJET (Quand on ramasse un sac) ---
@rpc("any_peer", "call_local", "reliable")
func _rpc_receive_pickup(item_dict: Dictionary, amount: int) -> void:
	var item = unpack_item(item_dict)
	if item != null:
		var remaining = add_item(item, amount)
		if remaining > 0:
			print("[INVENTAIRE] Plein ! On n'a pas pu tout ramasser.")
