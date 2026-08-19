extends Node

var player: Node3D
var stats: StatsComponent
var hit_timestamps: Array[float] = []
var last_calculated_hits: int = 0

const COMBO_WINDOW_MSEC: float = 4000.0 # 4 secondes
const DAMAGE_PER_HIT: float = 0.10 # 10%

func _ready() -> void:
	player = get_parent().get_parent()
	stats = player.get_node_or_null("%StatsComponent")
	if stats == null:
		stats = player.get_node_or_null("StatsComponent")
		
	if player.has_signal("player_hit_enemy"):
		player.player_hit_enemy.connect(_on_player_hit_enemy)

func _on_player_hit_enemy() -> void:
	hit_timestamps.append(Time.get_ticks_msec())
	print("Overwhelming Combo: Hit Registered! Total hits: ", hit_timestamps.size())

func _process(_delta: float) -> void:
	if stats == null: return
	
	var current_time = Time.get_ticks_msec()
	var cutoff_time = current_time - COMBO_WINDOW_MSEC
	
	# Nettoyer les vieux coups (qui ont plus de 4 secondes)
	while hit_timestamps.size() > 0 and hit_timestamps[0] < cutoff_time:
		hit_timestamps.pop_front()
		
	var current_hits = hit_timestamps.size()
	
	# Mettre à jour les stats seulement si le nombre de coups a changé
	if current_hits != last_calculated_hits:
		_update_combo_stats(current_hits)
		last_calculated_hits = current_hits

func _update_combo_stats(num_hits: int) -> void:
	stats.remove_modifier_by_source("overwhelming_combo")
	print("Overwhelming Combo: Buff Removed")
	
	if num_hits > 0:
		var bonus = num_hits * DAMAGE_PER_HIT
		# mod_type = 1 (PERCENT)
		stats.add_modifier("physical_damage", 1, bonus, "overwhelming_combo")
		print("Overwhelming Combo: Buff Applied: +", bonus*100, "%")

func _exit_tree() -> void:
	if player != null and player.has_signal("player_hit_enemy"):
		if player.player_hit_enemy.is_connected(_on_player_hit_enemy):
			player.player_hit_enemy.disconnect(_on_player_hit_enemy)
			
	if stats != null:
		stats.remove_modifier_by_source("overwhelming_combo")
	print("Overwhelming Combo: Buff Removed")
