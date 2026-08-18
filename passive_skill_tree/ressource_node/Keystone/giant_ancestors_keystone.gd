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
	if stat_name == "max_health":
		_update_bonus()

func _update_bonus() -> void:
	if stats == null: return
	
	stats.remove_modifier_by_source("giant_ancestors")
	
	var max_health_stat = stats.get_stat("max_health")
	if max_health_stat == null: return
	
	var total_percent = 0.0
	for mod in max_health_stat.modifiers:
		if mod.type == 1: # PERCENT
			# Check to avoid recursive loops if something else does the same
			if mod.id != "giant_ancestors":
				total_percent += mod.value
				
	if total_percent != 0.0:
		stats.add_modifier("area_of_effect", 1, total_percent, "giant_ancestors")

func _exit_tree() -> void:
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("giant_ancestors")
