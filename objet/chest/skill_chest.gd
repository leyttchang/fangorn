class_name SkillChest
extends Node3D

## Liste de tous les sorts du jeu qui peuvent être débloqués dans ce coffre
@export var all_possible_spells: Array[AbilityData] = []

var is_open: bool = false
var player_in_range: CharacterBody3D = null

func _ready() -> void:
	# Auto-chargement des sorts si l'array est vide dans l'inspecteur
	if all_possible_spells.is_empty():
		_auto_load_default_spells()

func _auto_load_default_spells() -> void:
	var spell_paths = [
		"res://scripts/abilities/fireball/Fireball.tres",
		"res://scripts/abilities/dash/dash.tres",
		"res://scripts/abilities/magic_shot/MagicShot.tres",
		"res://scripts/abilities/Burning_ground/BurningGround.tres",
		"res://scripts/abilities/Ice Crash/IceCrash.tres",
		"res://scripts/abilities/light_pilar/light_pillar.tres"
	]
	for path in spell_paths:
		if ResourceLoader.exists(path):
			all_possible_spells.append(load(path))

## Méthode appelée par l'InteractionComponent quand le joueur appuie sur E
func use(player: CharacterBody3D) -> void:
	if is_open: return
	player_in_range = player
	open_chest()

func open_chest() -> void:
	if is_open or player_in_range == null:
		return

	var spellbook_ui: SpellBookUI = _get_spellbook_ui(player_in_range)
	var skill_bar: SkillBarComponent = _get_skill_bar(player_in_range)

	if spellbook_ui == null:
		push_error("SkillChest : Impossible de trouver le SpellBookUI sur le joueur.")
		return

	# 1. Filtre des sorts : On ne garde QUE ceux que le joueur n'a PAS encore débloqués
	var available_locked_spells: Array[AbilityData] = []
	for spell in all_possible_spells:
		if spell == null:
			continue

		var already_unlocked = false

		# Vérification dans les sorts débloqués du SpellBookUI
		for unlocked in spellbook_ui.unlocked_spells:
			if unlocked != null and (unlocked == spell or unlocked.ability_name == spell.ability_name):
				already_unlocked = true
				break

		# Vérification dans la barre de compétences (SkillBarComponent)
		if not already_unlocked and skill_bar != null:
			for slot_spell in skill_bar.slots.values():
				if slot_spell != null and (slot_spell == spell or slot_spell.ability_name == spell.ability_name):
					already_unlocked = true
					break

		if not already_unlocked:
			available_locked_spells.append(spell)

	# 2. Si le joueur a déjà TOUS les sorts du jeu
	if available_locked_spells.is_empty():
		print("Le joueur a déjà débloqué tous les sorts disponibles !")
		return

	# 3. Tirage aléatoire parmi les sorts NON possédés
	var chosen_spell = available_locked_spells.pick_random()

	# 4. Déblocage du sort dans le SpellBookUI du joueur
	spellbook_ui.unlock_spell(chosen_spell)
	print("Nouveau sort débloqué : ", chosen_spell.ability_name)

	is_open = true

	# Destruction du coffre après ouverture
	queue_free()

func _get_spellbook_ui(player: Node) -> SpellBookUI:
	if player == null: return null
	for child in player.get_children():
		if child is SpellBookUI:
			return child
	return player.find_child("SpellBook*", true, false) as SpellBookUI

func _get_skill_bar(player: Node) -> SkillBarComponent:
	if player == null: return null
	for child in player.get_children():
		if child is SkillBarComponent:
			return child
	return player.find_child("SkillBar*", true, false) as SkillBarComponent
