class_name EquipmentComponent
extends Node

# Signal pour dire à l'UI et au système de combat que l'équipement a changé
signal equipment_changed(slot_name: String, item: ItemData)

# On a besoin d'accéder au sac à dos et aux stats du joueur
@export var inventory_component: InventoryComponent
@export var stats_component: StatsComponent

# Les emplacements disponibles sur ton personnage
var equipped_items: Dictionary = {
	"head": null,
	"chest": null,
	"legs": null,
	"feet": null,
	"main_hand": null,
	"off_hand": null,
	"ring_1": null,
	"ring_2": null
}

# --- ÉQUIPER UN OBJET ---
func equip_item(item: ItemData, slot_name: String) -> bool:
	if not equipped_items.has(slot_name):
		push_warning("Ce slot d'équipement n'existe pas : " + slot_name)
		return false

	# 1. Si on a déjà un objet équipé ici, on l'enlève et on le remet dans le sac
	if equipped_items[slot_name] != null:
		var success = unequip_item(slot_name)
		# Si l'inventaire est plein, on annule l'action !
		if not success:
			return false

	# 2. On place le nouvel objet dans le slot
	equipped_items[slot_name] = item

	# 3. On applique les bonus de l'objet sur le joueur
	_apply_item_stats(item)

	# 4. On prévient le reste du jeu
	equipment_changed.emit(slot_name, item)
	return true

# --- DÉSÉQUIPER UN OBJET ---
func unequip_item(slot_name: String) -> bool:
	if not equipped_items.has(slot_name) or equipped_items[slot_name] == null:
		return true # Rien à déséquiper, donc c'est "réussi"

	var item_to_remove = equipped_items[slot_name]

	# 1. On essaie de remettre l'objet dans l'inventaire
	if inventory_component != null:
		var leftover = inventory_component.add_item(item_to_remove, 1)
		if leftover > 0:
			print("Inventaire plein ! Impossible de retirer l'équipement.")
			return false

	# 2. On retire les bonus de cet objet du StatsComponent
	_remove_item_stats(item_to_remove)

	# 3. On vide le slot
	equipped_items[slot_name] = null
	equipment_changed.emit(slot_name, null)
	
	return true

# --- GESTION DES STATS (Le pont avec ton StatsComponent) ---
func _apply_item_stats(item: ItemData) -> void:
	if stats_component == null:
		return
		
	if item is WeaponItem:
		print("Une arme a été équipée : ", item.item_name)
		# Le test de +20% a été supprimé ici !
		# Plus tard, on lira les vraies stats du fichier .tres de l'arme
		
func _remove_item_stats(item: ItemData) -> void:
	if stats_component == null:
		return
		
	if item is WeaponItem:
		print("L'arme a été retirée : ", item.item_name)
		stats_component.remove_modifier_by_source(item.id)
