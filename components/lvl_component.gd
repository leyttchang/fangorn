class_name LevelComponent
extends Node3D

signal xp_changed(current_xp: int, xp_to_next: int)
signal level_up(new_level: int)

@export var current_level: int = 1
@export var current_xp: int = 0
@export var base_xp_requirement: int = 100
@export var xp_multiplier_per_level: float = 1.1

var xp_to_next_level: int = 100

func _ready() -> void:
	_calculate_xp_requirement()
	
func add_xp(amount: int) -> void:
	if amount <= 0: return
	
	current_xp += amount
	
	# Vérifie si on a assez d'XP pour monter de niveau (peut arriver plusieurs fois d'un coup si on gagne beaucoup d'XP)
	while current_xp >= xp_to_next_level:
		_level_up()
		
	# On émet le signal pour que l'interface puisse mettre à jour la barre d'XP
	xp_changed.emit(current_xp, xp_to_next_level)

func _level_up() -> void:
	# On retire l'XP requise pour le niveau actuel
	current_xp -= xp_to_next_level
	current_level += 1
	
	# On recalcule le besoin pour le niveau suivant
	_calculate_xp_requirement()
	
	# On prévient tout le monde (l'UI, le joueur pour gagner des stats, etc.)
	level_up.emit(current_level)

func _calculate_xp_requirement() -> void:
	# Formule classique : 100 au niveau 1, 150 au niveau 2, 225 au niveau 3, etc.
	xp_to_next_level = int(base_xp_requirement * pow(xp_multiplier_per_level, current_level - 1))
