class_name InteractiveChest
extends Node3D

@export_group("Loot Configuration")
@export var possible_bases: Array[EquipmentItem] = []
@export var all_possible_affixes: Array[AffixData] = []

@export_group("Quantité d'objets")
@export_range(0.0, 100.0, 1.0, "suffix:%") var chance_2nd_item: float = 75.0
@export_range(0.0, 100.0, 1.0, "suffix:%") var chance_3rd_item: float = 30.0
@export_range(0.0, 100.0, 1.0, "suffix:%") var chance_4th_item: float = 5.0

@export_group("Probabilités de Rareté")
@export var weight_common: int = 25
@export var weight_magic: int = 35
@export var weight_rare: int = 30
@export var weight_legendary: int = 10

var is_open: bool = false
var player_in_range: CharacterBody3D = null
@onready var chest_inventory: InventoryComponent = $InventoryComponent
var has_generated_loot: bool = false

func _ready() -> void:
	# === AUTO-CHARGEMENT PRATIQUE ===
	if possible_bases.is_empty():
		possible_bases.append(preload("res://item/armes/test_sword_stats.tres"))
		possible_bases.append(preload("res://item/armes/test_axe.tres"))
		possible_bases.append(preload("res://item/armes/spear_test.tres"))
		possible_bases.append(preload("res://item/armures/chest/heavy_armor.tres"))
		possible_bases.append(preload("res://item/armures/feet/heavy_boots.tres"))
	
	if all_possible_affixes.is_empty():
		all_possible_affixes = GameData.get_all_affixes()

## Méthode appelée par l'InteractionComponent quand le joueur appuie sur E
func use(player: CharacterBody3D) -> void:
	if is_open: return
	player_in_range = player
	open_chest()

func open_chest() -> void:
	if is_open or player_in_range == null: return
	is_open = true
		
	if possible_bases.is_empty() or all_possible_affixes.is_empty():
		print("Attention: Le coffre n'a pas de bases ou d'affixes configurés dans l'inspecteur !")
		return
		
	# On ne génère le loot qu'une seule fois
	if not has_generated_loot:
		has_generated_loot = true
		var ilvl = _get_ilvl_from_wave()
		
		var num_items = 1
		if randf() * 100.0 <= chance_2nd_item:
			num_items += 1
		if randf() * 100.0 <= chance_3rd_item:
			num_items += 1
		if randf() * 100.0 <= chance_4th_item:
			num_items += 1
			
		for i in range(num_items):
			var rarity = _get_random_rarity()
			var base_item = possible_bases.pick_random()
			var new_item = ItemGenerator.generate_equipment(base_item, ilvl, rarity, all_possible_affixes)
			chest_inventory.add_item(new_item, 1)
			
	var inv_ui = player_in_range.get_node_or_null("InventoryUI")
	if inv_ui == null:
		# L'UI de l'inventaire est peut-être ailleurs dans la scène
		var canvas = get_tree().get_nodes_in_group("PlayerUI") # À adapter selon la structure, on tente une recherche
		# Pour l'instant on suppose que le joueur y a accès
		if player_in_range.has_method("get_inventory_ui"):
			inv_ui = player_in_range.get_inventory_ui()
			
	if inv_ui != null:
		if not inv_ui.inventory_closed.is_connected(_on_inventory_closed):
			inv_ui.inventory_closed.connect(_on_inventory_closed)
		inv_ui.open_with_chest(chest_inventory)
	else:
		print("Erreur: Impossible de trouver l'InventoryUI du joueur !")

func _on_inventory_closed() -> void:
	is_open = false
	if chest_inventory.is_empty():
		queue_free()

func _get_ilvl_from_wave() -> int:
	var wave_num = 1
	var spawners = get_tree().get_nodes_in_group("SmartSpawner")
	if not spawners.is_empty():
		wave_num = spawners[0].current_wave
		
	return max(1, int(float(wave_num) / 1.5))

func _get_random_rarity() -> ItemData.Rarity:
	var total_weight = weight_common + weight_magic + weight_rare + weight_legendary
	var roll = randi_range(1, total_weight)
	
	if roll <= weight_common:
		return ItemData.Rarity.COMMON
	roll -= weight_common
	
	if roll <= weight_magic:
		return ItemData.Rarity.MAGIC
	roll -= weight_magic
	
	if roll <= weight_rare:
		return ItemData.Rarity.RARE
		
	return ItemData.Rarity.LEGENDARY
