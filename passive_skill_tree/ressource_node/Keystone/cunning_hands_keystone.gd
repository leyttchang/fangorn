extends Node

var player: Node3D
var stats: StatsComponent
var lvl_comp: LevelComponent

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
		
	lvl_comp = player.get_node_or_null("lvl_component")
	
	if stats != null and lvl_comp != null:
		lvl_comp.level_up.connect(_on_level_up)
		_update_bonus(lvl_comp.current_level)

func _on_level_up(new_level: int) -> void:
	_update_bonus(new_level)

func _update_bonus(level: int) -> void:
	if stats == null: return
	
	stats.remove_modifier_by_source("cunning_hands")
	# Ajout d'un FLAT modifier = level
	# 0 = FLAT
	stats.add_modifier("flat_physical_damage", 0, float(level), "cunning_hands")

func _exit_tree() -> void:
	if lvl_comp != null and lvl_comp.level_up.is_connected(_on_level_up):
		lvl_comp.level_up.disconnect(_on_level_up)
	if stats != null:
		stats.remove_modifier_by_source("cunning_hands")
