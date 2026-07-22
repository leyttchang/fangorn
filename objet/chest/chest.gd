class_name InteractiveChest
extends Node3D

@export_group("Loot Configuration")
@export var possible_bases: Array[EquipmentItem] = []
@export var all_possible_affixes: Array[AffixData] = []

@export_group("Probabilités de Rareté")
@export var weight_common: int = 25
@export var weight_magic: int = 35
@export var weight_rare: int = 30
@export var weight_legendary: int = 10

var is_open: bool = false
var player_in_range: CharacterBody3D = null

func _ready() -> void:
	# === AUTO-CHARGEMENT PRATIQUE ===
	if possible_bases.is_empty():
		possible_bases.append(preload("res://item/armes/test_sword_stats.tres"))
		possible_bases.append(preload("res://item/armes/test_axe.tres"))
		possible_bases.append(preload("res://item/armes/spear_test.tres"))
		possible_bases.append(preload("res://item/armures/chest/heavy_armor.tres"))
		possible_bases.append(preload("res://item/armures/feet/heavy_boots.tres"))
	
	if all_possible_affixes.is_empty():
		all_possible_affixes.append(preload("res://item/affixes/affix_health.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_armor.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_attack_speed.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_movement_speed.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_physical_damage.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_magic_damage.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_cd_red.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_area_of_effect.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_knockback_power.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_knockback_resistance.tres"))
		all_possible_affixes.append(preload("res://item/affixes/affix_casting_speed.tres"))

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
		
	var ilvl = _get_ilvl_from_wave()
	var rarity = _get_random_rarity()
	var base_item = possible_bases.pick_random()
	var new_item = ItemGenerator.generate_equipment(base_item, ilvl, rarity, all_possible_affixes)
	
	var inv_comp = player_in_range.get_node_or_null("InventoryComponent")
	if inv_comp:
		inv_comp.add_item(new_item, 1)
		print("Coffre ouvert ! " + new_item.item_name + " (ilvl: " + str(ilvl) + ") ajouté à l'inventaire.")
	
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
