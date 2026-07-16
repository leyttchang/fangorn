class_name StatsComponent
extends Node

# On demande à Godot de nous afficher une case pour glisser notre fichier .tres
@export var starting_stats: EntityStats 

# Le dictionnaire qui va contenir nos objets Stat
var _stats: Dictionary = {}

func _ready():
	# 1. Sécurité : On vérifie qu'on a bien assigné un fichier de stats
	if starting_stats == null:
		push_error("StatsComponent sur " + get_parent().name + " : Pas de starting_stats assigné !")
		return
		
	# 2. On initialise le dictionnaire avec des objets Stat.new()
	_stats["max_health"] = Stat.new(starting_stats.max_health)
	_stats["armor"] = Stat.new(starting_stats.armor)
	_stats["physical_damage"] = Stat.new(starting_stats.physical_damage)
	_stats["magic_damage"] = Stat.new(starting_stats.magic_damage)
	_stats["attack_speed"] = Stat.new(starting_stats.attack_speed)
	_stats["cd_red"] = Stat.new(starting_stats.cd_red)
	_stats["area_of_effect"] = Stat.new(starting_stats.area_of_effect)
	_stats["movement_speed"] = Stat.new(starting_stats.movement_speed)
	_stats["knockback_power"] = Stat.new(starting_stats.knockback_power)
	_stats["knockback_resistance"] = Stat.new(starting_stats.knockback_resistance)
	_stats["casting_speed"] = Stat.new(starting_stats.casting_speed)
# Fonction pour récupérer rapidement la valeur finale (ex: pour taper un ennemi)
func get_stat_value(stat_name: String) -> float:
	if _stats.has(stat_name):
		return _stats[stat_name].get_value()
	
	push_warning("La stat demandée n'existe pas : " + stat_name)
	return 0.0

# Fonction pour récupérer l'objet Stat complet (ex: pour lui ajouter un buff)
func get_stat(stat_name: String) -> Stat:
	if _stats.has(stat_name):
		return _stats[stat_name]
	return null

# --- NOUVELLES FONCTIONS : LE PONT DES MODIFICATEURS ---
func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	var stat = get_stat(stat_name)
	
	if stat != null:
		if stat.has_method("add_modifier"):
			# LA CORRECTION EST ICI : 
			# On respecte l'ordre exact de ton _init() : id, valeur, type
			var new_modifier = StatModifier.new(source_id, value, mod_type)
			stat.add_modifier(new_modifier)
		else:
			push_warning("Attention, la classe Stat n'a pas de fonction add_modifier()")

func remove_modifier_by_source(source_id: String) -> void:
	for stat_name in _stats:
		var stat = _stats[stat_name]
		if stat.has_method("remove_modifier"):
			stat.remove_modifier(source_id)
