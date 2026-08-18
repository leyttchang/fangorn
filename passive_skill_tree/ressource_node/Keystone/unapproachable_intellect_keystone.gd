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
	
	# Retirer l'ancien buff
	stats.remove_modifier_by_source("unapproachable_intellect")
	
	# Calculer le nouveau bonus (30% du max mana)
	var current_mana = stats.get_stat_value("max_mana")
	var bonus_health = current_mana * 0.30
	
	# Ajouter le nouveau buff FLAT (0 = FLAT)
	stats.add_modifier("max_health", 0, bonus_health, "unapproachable_intellect")

func _exit_tree() -> void:
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("unapproachable_intellect")
