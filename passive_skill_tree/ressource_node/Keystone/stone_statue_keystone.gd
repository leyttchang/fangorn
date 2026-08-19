extends Node

var player: Node3D
var stats: StatsComponent

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
	
	if stats != null:
		# Double your armor rating (+100% ARMOR)
		# 1 = ModType.PERCENT
		stats.add_modifier("armor", 1, 1.0, "stone_statue")

func _exit_tree() -> void:
	if stats != null:
		stats.remove_modifier_by_source("stone_statue")
