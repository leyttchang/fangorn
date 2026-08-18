extends Node

var player: Node3D
var stats: StatsComponent
var is_updating: bool = false

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
	
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		_apply_elementalist()

func _on_stat_changed(stat_name: String, _new_value: float) -> void:
	if is_updating: return
	
	if stat_name in ["fire_damage", "ice_damage", "lightning_damage"]:
		_apply_elementalist()

func _apply_elementalist() -> void:
	if stats == null: return
	
	is_updating = true
	
	stats.remove_modifier_by_source("elementalist")
	
	var fire_pct = _get_percent("fire_damage")
	var ice_pct = _get_percent("ice_damage")
	var light_pct = _get_percent("lightning_damage")
	
	var min_pct = min(fire_pct, min(ice_pct, light_pct))
	
	if min_pct > 0.0:
		stats.add_modifier("fire_damage", 1, min_pct, "elementalist")
		stats.add_modifier("ice_damage", 1, min_pct, "elementalist")
		stats.add_modifier("lightning_damage", 1, min_pct, "elementalist")
		
	is_updating = false

func _get_percent(stat_name: String) -> float:
	var stat_obj = stats.get_stat(stat_name)
	if stat_obj == null: return 0.0
	
	var total = 0.0
	for mod in stat_obj.modifiers:
		if mod.type == 1 and mod.id != "elementalist":
			total += mod.value
	return total

func _exit_tree() -> void:
	if stats != null:
		stats.stat_changed.disconnect(_on_stat_changed)
		stats.remove_modifier_by_source("elementalist")
