extends Node

var player: Node3D
var skill_bar: SkillBarComponent
var health_comp: HealthComponent
var stats: StatsComponent
var is_updating: bool = false

# Liste des régénérations actives
var active_regens: Array[Dictionary] = []

func _ready() -> void:
	player = get_parent().get_parent()
	
	skill_bar = player.get_node_or_null("%SkillBarComponent")
	if skill_bar == null:
		skill_bar = player.get_node_or_null("SkillBarComponent")
		
	health_comp = player.get_node_or_null("%HealthComponent")
	if health_comp == null:
		health_comp = player.get_node_or_null("HealthComponent")
		
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
		
	if skill_bar != null:
		skill_bar.current_casting_resource = skill_bar.CastingResource.HEALTH
		skill_bar.health_spent_for_spell.connect(_on_health_spent)
		
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_apply_renouncement()

func _on_health_spent(amount: float) -> void:
	var amount_per_sec = amount / 5.0
	active_regens.append({
		"amount_per_sec": amount_per_sec,
		"time_left": 5.0
	})

func _on_stat_changed(stat_name: String, _new_value: float) -> void:
	if is_updating: return
	if stat_name in ["max_mana", "mana_regen"]:
		_apply_renouncement()

func _apply_renouncement() -> void:
	if stats == null: return
	is_updating = true
	_force_stat("max_mana", 0.0)
	_force_stat("mana_regen", 0.0)
	is_updating = false

func _force_stat(stat_name: String, target_value: float) -> void:
	stats.remove_modifier_by_source("renouncement_" + stat_name)
	
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
	stats.add_modifier(stat_name, 0, flat_needed, "renouncement_" + stat_name)

func _process(delta: float) -> void:
	if active_regens.is_empty() or health_comp == null:
		return
		
	var total_heal_this_frame = 0.0
	for i in range(active_regens.size() - 1, -1, -1):
		var regen = active_regens[i]
		var time_to_process = min(delta, regen.time_left)
		total_heal_this_frame += regen.amount_per_sec * time_to_process
		regen.time_left -= time_to_process
		
		if regen.time_left <= 0.0:
			active_regens.remove_at(i)
			
	if total_heal_this_frame > 0.0:
		health_comp.heal(total_heal_this_frame)

func _exit_tree() -> void:
	if skill_bar != null:
		skill_bar.current_casting_resource = skill_bar.CastingResource.MANA
		if skill_bar.health_spent_for_spell.is_connected(_on_health_spent):
			skill_bar.health_spent_for_spell.disconnect(_on_health_spent)
			
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("renouncement_max_mana")
		stats.remove_modifier_by_source("renouncement_mana_regen")
