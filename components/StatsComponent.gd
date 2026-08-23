class_name StatsComponent
extends Node

# On demande  Godot de nous afficher une case pour glisser notre fichier .tres
@export var starting_stats: EntityStats 

# Le dictionnaire qui va contenir nos objets Stat
var _stats: Dictionary = {}
signal stat_changed(stat_name: String, new_value: float)
func _ready():
	# 1. Scurit : On vrifie qu'on a bien assign un fichier de stats
	if starting_stats == null:
		push_error("StatsComponent sur " + get_parent().name + " : Pas de starting_stats assign !")
		return
		
	# 2. On initialise le dictionnaire avec des objets Stat.new()
	_stats["max_health"] = Stat.new(starting_stats.max_health)
	_stats["max_mana"] = Stat.new(starting_stats.max_mana)
	_stats["mana_regen"] = Stat.new(starting_stats.mana_regen)
	_stats["armor"] = Stat.new(starting_stats.armor)
	_stats["flat_physical_damage"] = Stat.new(starting_stats.flat_physical_damage)
	_stats["physical_damage"] = Stat.new(starting_stats.physical_damage)
	_stats["magic_damage"] = Stat.new(starting_stats.magic_damage)
	_stats["fire_damage"] = Stat.new(starting_stats.fire_damage)
	_stats["ice_damage"] = Stat.new(starting_stats.ice_damage)
	_stats["lightning_damage"] = Stat.new(starting_stats.lightning_damage)
	_stats["attack_speed"] = Stat.new(starting_stats.attack_speed)
	_stats["cd_red"] = Stat.new(starting_stats.cd_red)
	_stats["area_of_effect"] = Stat.new(starting_stats.area_of_effect)
	_stats["movement_speed"] = Stat.new(starting_stats.movement_speed)
	_stats["knockback_power"] = Stat.new(starting_stats.knockback_power)
	_stats["knockback_resistance"] = Stat.new(starting_stats.knockback_resistance)
	_stats["casting_speed"] = Stat.new(starting_stats.casting_speed)
	_stats["xp_reward"] = Stat.new(starting_stats.xp_reward)
	_stats["fire_resistance"] = Stat.new(starting_stats.fire_resistance)
	_stats["ice_resistance"] = Stat.new(starting_stats.ice_resistance)
	_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)
	_stats["action_speed"] = Stat.new(starting_stats.action_speed)
	_stats["damage_taken_multiplier"] = Stat.new(starting_stats.damage_taken_multiplier)
# Fonction pour rcuprer rapidement la valeur finale (ex: pour taper un ennemi)
func get_stat_value(stat_name: String) -> float:
	if _stats.has(stat_name):
		return _stats[stat_name].get_value()
	
	push_warning("La stat demande n'existe pas : " + stat_name)
	return 0.0

# Fonction pour rcuprer l'objet Stat complet (ex: pour lui ajouter un buff)
func get_stat(stat_name: String) -> Stat:
	if _stats.has(stat_name):
		return _stats[stat_name]
	return null

# --- NOUVELLES FONCTIONS : LE PONT DES MODIFICATEURS ---
func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	var stat = get_stat(stat_name)
	if stat != null:
		if stat.has_method("add_modifier"):
			var new_modifier = StatModifier.new(source_id, value, mod_type)
			stat.add_modifier(new_modifier)
			
			# NOUVEAU : On prvient le reste du jeu de la nouvelle valeur !
			stat_changed.emit(stat_name, stat.get_value())
		else:
			push_warning("Attention, la classe Stat n'a pas de fonction add_modifier()")

func remove_modifier_by_source(source_id: String) -> void:
	for stat_name in _stats:
		var stat = _stats[stat_name]
		if stat.has_method("remove_modifier"):
			# On garde l'ancienne valeur en mmoire pour voir si a a vraiment chang
			var old_value = stat.get_value()
			stat.remove_modifier(source_id)
			
			# NOUVEAU : Si la stat a chang aprs le retrait, on prvient le jeu
			if stat.get_value() != old_value:
				stat_changed.emit(stat_name, stat.get_value())
