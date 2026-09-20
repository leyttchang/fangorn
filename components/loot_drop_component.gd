class_name LootDropComponent
extends Node3D

## Composant gérant le drop d'objets (sacs au sol) à la mort d'une entité ou sur commande.
## Doit être exécuté côté serveur pour le multijoueur.

signal item_dropped(item: EquipmentItem, bag: Node3D)

@export_category("Probabilités de Drop")
## Pourcentage de chance de drop à la mort (0 - 100%)
@export_range(0.0, 100.0, 0.1, "suffix:%") var drop_chance: float = 25.0

## Multiplicateur global de chance de drop (ex: 2.0 pour doubler les chances)
@export var drop_chance_multiplier: float = 1.0

## Multiplicateur de Magic Find (augmente la proportion de raretés élevées)
@export var magic_find_multiplier: float = 1.0

@export_group("Quantité d'objets")
@export var min_drops: int = 1
@export var max_drops: int = 1
## Chance d'avoir un objet additionnel (0 - 100%)
@export_range(0.0, 100.0, 0.1, "suffix:%") var extra_drop_chance: float = 0.0

@export_group("Poids des Raretés")
@export var weight_common: int = 60
@export var weight_magic: int = 28
@export var weight_rare: int = 10
@export var weight_legendary: int = 2

@export_group("Niveau de l'objet (ilvl)")
## Si > 0, force cet ilvl. Si 0, calcule automatiquement selon la vague ou la distance
@export var ilvl_override: int = 0

@export_group("Tables de Loot")
## Liste des bases d'équipement possibles. Si vide, charge automatiquement tout GameData.get_all_bases()
@export var possible_bases: Array[EquipmentItem] = []
## Liste des affixes possibles. Si vide, charge automatiquement GameData.get_all_affixes()
@export var all_possible_affixes: Array[AffixData] = []

@export_group("Références & Scènes")
## Scène du sac d'objet physique au sol
@export var bag_scene: PackedScene = preload("res://objet/item_bag/item_bag.tscn")
## Composant de vie à surveiller. Si nul, cherche automatiquement sur le parent
@export var health_component: HealthComponent = null


func _ready() -> void:
	# === AUTO-CHARGEMENT PRATIQUE DES BASES ET AFFIXES ===
	if possible_bases.is_empty():
		possible_bases = GameData.get_all_bases().duplicate()
		
	if all_possible_affixes.is_empty():
		all_possible_affixes = GameData.get_all_affixes()
		
	# === DÉTECTION DU HEALTH COMPONENT ===
	if health_component == null:
		var parent = get_parent()
		if parent != null:
			health_component = parent.get_node_or_null("HealthComponent")
			if health_component == null:
				health_component = parent.find_child("HealthComponent*", true, false)
				
	if health_component != null:
		if not health_component.died.is_connected(_on_health_component_died):
			health_component.died.connect(_on_health_component_died)


func _on_health_component_died() -> void:
	# Seul le serveur gère la génération et l'instanciation physique du loot
	if not multiplayer.is_server():
		return
	drop_loot()


## Déclenche le jet de loot et fait pop les sacs au sol
func drop_loot() -> void:
	if not multiplayer.is_server():
		return
		
	# 1. Jet de chance d'obtenir un drop
	var effective_chance = drop_chance * drop_chance_multiplier
	if randf() * 100.0 > effective_chance:
		return
		
	if possible_bases.is_empty():
		push_warning("[LootDropComponent] Aucune base d'équipement disponible !")
		return
		
	# 2. Nombre de drops à générer
	var count = randi_range(min_drops, max_drops)
	if extra_drop_chance > 0.0 and randf() * 100.0 <= extra_drop_chance:
		count += 1
		
	var ilvl = _resolve_ilvl()
	
	for i in range(count):
		_spawn_loot_bag(ilvl)


## Déclencheur direct (alias utile pour des triggers, coffres ou events)
func trigger_loot() -> void:
	drop_loot()


## Génère l'équipement et instancie le sac physique sur le réseau
func _spawn_loot_bag(ilvl: int) -> Node3D:
	if bag_scene == null or possible_bases.is_empty():
		return null
		
	# Choix aléatoire d'une base et calcul de la rareté
	var base_item: EquipmentItem = possible_bases.pick_random()
	if base_item == null:
		return null
		
	var rarity = _get_random_rarity()
	var new_item: EquipmentItem = ItemGenerator.generate_equipment(
		base_item,
		ilvl,
		rarity,
		all_possible_affixes
	)
	
	var bag = bag_scene.instantiate()
	bag.item_data = new_item
	bag.item_amount = 1
	if "rarity" in bag:
		bag.rarity = new_item.rarity
	
	# Trouver le noeud NetworkObjects (identique à inventory_componant.gd)
	var network_objects = _find_network_objects()
	if network_objects != null:
		network_objects.add_child(bag, true)
	else:
		var parent = get_parent()
		if parent != null and parent.get_parent() != null:
			parent.get_parent().add_child(bag, true)
		elif get_tree().current_scene != null:
			get_tree().current_scene.add_child(bag, true)
		else:
			add_child(bag, true)
			
	# Positionnement et impulsion physique satisfaisante (pop ARPG)
	var spawn_pos = global_position + Vector3(0.0, 1.0, 0.0)
	bag.global_position = spawn_pos
	
	var angle = randf() * TAU
	var h_force = randf_range(1.5, 3.5)
	var v_force = randf_range(3.0, 4.5)
	bag.linear_velocity = Vector3(cos(angle) * h_force, v_force, sin(angle) * h_force)
	bag.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	
	item_dropped.emit(new_item, bag)
	return bag


## Trouve NetworkObjects en remontant l'arbre ou depuis la scène courante
func _find_network_objects() -> Node:
	var root = get_parent()
	while root != null:
		if root.has_node("NetworkObjects"):
			return root.get_node("NetworkObjects")
		root = root.get_parent()
		
	var cur_scene = get_tree().current_scene
	if cur_scene != null and cur_scene.has_node("NetworkObjects"):
		return cur_scene.get_node("NetworkObjects")
		
	return null


## Résout l'ilvl de manière contextuelle (SmartSpawner ou distance de zone)
func _resolve_ilvl() -> int:
	if ilvl_override > 0:
		return ilvl_override
		
	# Mode Vagues (SmartSpawner)
	var spawners = get_tree().get_nodes_in_group("SmartSpawner")
	if not spawners.is_empty():
		var spawner = spawners[0]
		if "current_wave" in spawner:
			var wave = spawner.current_wave
			if wave > 0:
				return max(1, int(float(wave) / 1.5))
				
	# Mode Exploration / Normal : calculé selon l'éloignement au spawn (0,0,0)
	var dist = global_position.length()
	var lvl_from_dist = int(dist / 200.0) + 1
	return max(1, lvl_from_dist)


## Sélectionne une rareté pondérée avec l'influence du Magic Find
func _get_random_rarity() -> ItemData.Rarity:
	var mf = max(0.0, magic_find_multiplier)
	var w_common = max(1, weight_common)
	var w_magic = max(0, int(round(weight_magic * (1.0 + (mf - 1.0) * 0.5)))) if mf > 1.0 else int(round(weight_magic * mf))
	var w_rare = max(0, int(round(weight_rare * mf)))
	var w_legendary = max(0, int(round(weight_legendary * (mf * 1.2)))) if mf > 1.0 else int(round(weight_legendary * mf))
	
	var total_weight = w_common + w_magic + w_rare + w_legendary
	if total_weight <= 0:
		return ItemData.Rarity.COMMON
		
	var roll = randi_range(1, total_weight)
	if roll <= w_common:
		return ItemData.Rarity.COMMON
	roll -= w_common
	
	if roll <= w_magic:
		return ItemData.Rarity.MAGIC
	roll -= w_magic
	
	if roll <= w_rare:
		return ItemData.Rarity.RARE
		
	return ItemData.Rarity.LEGENDARY


# ==========================================================
# MÉTHODES UTILITAIRES POUR LE GAMEPLAY / CODE
# ==========================================================

## Modifie dynamiquement la chance de drop
func set_drop_chance(chance: float) -> void:
	drop_chance = clamp(chance, 0.0, 100.0)

## Multiplie la chance de loot (ex: buffs, événements)
func set_drop_multiplier(multiplier: float) -> void:
	drop_chance_multiplier = max(0.0, multiplier)

## Définit le magic find
func set_magic_find(mf: float) -> void:
	magic_find_multiplier = max(0.0, mf)

## Configure ce mob comme un Élite (plus de loot, meilleures raretés)
func setup_as_elite(loot_mult: float = 2.0, mf: float = 1.5) -> void:
	drop_chance_multiplier = loot_mult
	magic_find_multiplier = mf
	min_drops = 1
	max_drops = 2
	extra_drop_chance = 35.0

## Configure ce mob comme un Boss (loot garanti, plusieurs objets, raretés élevées)
func setup_as_boss(min_items: int = 2, max_items: int = 4) -> void:
	drop_chance = 100.0
	drop_chance_multiplier = 1.0
	magic_find_multiplier = 2.5
	min_drops = min_items
	max_drops = max_items
	weight_common = 15
	weight_magic = 40
	weight_rare = 35
	weight_legendary = 10
