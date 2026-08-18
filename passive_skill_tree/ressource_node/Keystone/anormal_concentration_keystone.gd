extends Node

var player: Node3D
var stats: StatsComponent

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
	
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_update_bonus()

func _on_stat_changed(stat_name: String, _new_value: float) -> void:
	if stat_name == "max_mana":
		_update_bonus()

func _update_bonus() -> void:
	if stats == null: return
	
	stats.remove_modifier_by_source("anormal_concentration")
	
	var max_mana_stat = stats.get_stat("max_mana")
	if max_mana_stat == null: return
	
	var total_percent = 0.0
	for mod in max_mana_stat.modifiers:
		if mod.type == 1: # PERCENT
			if mod.id != "anormal_concentration":
				total_percent += mod.value
				
	if total_percent != 0.0:
		stats.add_modifier("armor", 1, total_percent, "anormal_concentration")

func _exit_tree() -> void:
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("anormal_concentration")
