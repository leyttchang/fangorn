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
	if amount <= 0:
		return

	current_xp += amount

	while current_xp >= xp_to_next_level:
		_level_up()

	xp_changed.emit(current_xp, xp_to_next_level)

	# Distribue aussi l'XP gagnée aux sorts actuellement équipés dans la barre de sorts du joueur
	var parent_node: Node = get_parent()
	if parent_node != null:
		var spellbook: Node = parent_node.get_node_or_null("SpellBook_UI")
		if spellbook != null and spellbook.has_method("on_player_xp_gained"):
			spellbook.call("on_player_xp_gained", amount)


@rpc("any_peer", "call_local", "reliable")
func _rpc_add_xp(amount: int) -> void:
	if get_parent().is_multiplayer_authority():
		add_xp(amount)


func _level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	_calculate_xp_requirement()
	level_up.emit(current_level)


func _calculate_xp_requirement() -> void:
	xp_to_next_level = int(base_xp_requirement * pow(xp_multiplier_per_level, current_level - 1))
