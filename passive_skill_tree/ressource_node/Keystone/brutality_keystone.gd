extends Node

var player: Node3D
var stats: StatsComponent
var skill_bar: SkillBarComponent
var is_updating: bool = false

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
	
	skill_bar = player.get_node_or_null("SkillBarComponent")
	if skill_bar == null:
		skill_bar = player.get_node_or_null("%SkillBarComponent")
		
	if skill_bar != null:
		skill_bar.can_cast_spells = false
		
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_apply_brutality()

func _on_stat_changed(stat_name: String, _new_value: float) -> void:
	if is_updating: return
	
	if stat_name in ["fire_damage", "ice_damage", "lightning_damage"]:
		_apply_brutality()

func _apply_brutality() -> void:
	if stats == null: return
	
	is_updating = true
	
	# 1. +50% physical damage
	stats.remove_modifier_by_source("brutality_phys")
	stats.add_modifier("physical_damage", 1, 0.50, "brutality_phys")
	
	# 2. Force stats
	_force_stat("fire_damage", 0.0)
	_force_stat("ice_damage", 0.0)
	_force_stat("lightning_damage", 0.0)
	
	is_updating = false

func _force_stat(stat_name: String, target_value: float) -> void:
	stats.remove_modifier_by_source("brutality_" + stat_name)
	
	var stat_obj = stats.get_stat(stat_name)
	if stat_obj == null: return
	
	var percent_multiplier = 0.0
	var other_flat = 0.0
	
	for mod in stat_obj.modifiers:
		if mod.type == 1: # PERCENT
			percent_multiplier += mod.value
		elif mod.type == 0: # FLAT
			other_flat += mod.value
			
	var denom = 1.0 + percent_multiplier
	if denom == 0.0: denom = 0.0001
	
	var flat_needed = (target_value / denom) - stat_obj.base_value - other_flat
	
	# Add the compensating flat modifier
	stats.add_modifier(stat_name, 0, flat_needed, "brutality_" + stat_name)

func _exit_tree() -> void:
	if skill_bar != null:
		skill_bar.can_cast_spells = true
		
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("brutality_phys")
		stats.remove_modifier_by_source("brutality_fire_damage")
		stats.remove_modifier_by_source("brutality_ice_damage")
		stats.remove_modifier_by_source("brutality_lightning_damage")
