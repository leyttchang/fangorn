class_name InteractiveChest
extends Area3D

@export_group("Loot Configuration")
@export var possible_bases: Array[EquipmentItem] = []
@export var all_possible_affixes: Array[AffixData] = []

@export_group("Probabilités de Rareté")
## Remplissez ces valeurs. Le total n'a pas besoin de faire 100, le jeu fera le ratio automatiquement.
@export var weight_common: int = 25
@export var weight_magic: int = 35
@export var weight_rare: int = 30
@export var weight_legendary: int = 10

var is_open: bool = false
var player_in_range: CharacterBody3D = null

# On cherche un Label3D enfant pour afficher le texte "Press E"
@onready var prompt_label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	if prompt_label:
		prompt_label.text = "Press E to open"
		prompt_label.hide()
		
	# On s'assure que le composant surveille les corps physiques
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# === AUTO-CHARGEMENT PRATIQUE ===
	# Si vous n'avez rien mis dans l'inspecteur, on charge tout automatiquement !
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

func _unhandled_input(event: InputEvent) -> void:
	# Si le joueur est à côté, que ce n'est pas ouvert, et qu'il appuie sur E
	if not is_open and player_in_range != null:
		if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed:
			open_chest()

func open_chest() -> void:
	is_open = true
	if prompt_label:
		prompt_label.hide()
		
	if possible_bases.is_empty() or all_possible_affixes.is_empty():
		print("Attention: Le coffre n'a pas de bases ou d'affixes configurés dans l'inspecteur !")
		return
		
	# 1. Calcul du ilvl basé sur la vague actuelle
	var ilvl = _get_ilvl_from_wave()
	
	# 2. Détermination de la rareté
	var rarity = _get_random_rarity()
	
	# 3. Choix d'une base au hasard
	var base_item = possible_bases.pick_random()
	
	# 4. Génération de l'objet complet
	var new_item = ItemGenerator.generate_equipment(base_item, ilvl, rarity, all_possible_affixes)
	
	# 5. Ajout à l'inventaire du joueur
	var inv_comp = player_in_range.get_node_or_null("InventoryComponent")
	if inv_comp:
		inv_comp.add_item(new_item, 1)
		print("Coffre ouvert ! " + new_item.item_name + " (ilvl: " + str(ilvl) + ") ajouté à l'inventaire.")
	
	# (Optionnel) Jouer une animation d'ouverture ici si vous en avez une,
	# Pour l'instant, on détruit simplement le coffre pour ne pas le rouvrir.
	queue_free()

func _get_ilvl_from_wave() -> int:
	var wave_num = 1
	var spawners = get_tree().get_nodes_in_group("SmartSpawner")
	if not spawners.is_empty():
		wave_num = spawners[0].current_wave
		
	# La formule demandée : ilvl = vague / 1.5
	return max(1, int(float(wave_num) / 1.5))

func _get_random_rarity() -> ItemData.Rarity:
	var total_weight = weight_common + weight_magic + weight_rare + weight_legendary
	# Tirage entre 1 et le total des poids
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

func _on_body_entered(body: Node3D) -> void:
	if is_open: return
	# Vérifie si le corps qui entre est le joueur
	if body is CharacterBody3D and body.has_node("InventoryComponent"):
		player_in_range = body
		if prompt_label:
			prompt_label.show()

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if prompt_label:
			prompt_label.hide()
