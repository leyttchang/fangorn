class_name ManaComponent
extends Node

signal mana_changed(current_mana: float, max_mana: float)

@export var stats_component: StatsComponent

var current_mana: float = 0.0
var _known_max_mana: float = 0.0

func _ready() -> void:
	if stats_component == null:
		push_error("ManaComponent sur " + get_parent().name + " : StatsComponent manquant !")
		set_process(false)
		return
		
	# Initialisation
	_known_max_mana = stats_component.get_stat_value("max_mana")
	current_mana = _known_max_mana
	
	# S'abonner aux changements de stats pour ajuster le mana max dynamiquement
	stats_component.stat_changed.connect(_on_stat_changed)
	
	# Envoyer le signal initial au cas où l'UI écoute
	call_deferred("_emit_initial")

func _emit_initial() -> void:
	mana_changed.emit(current_mana, _known_max_mana)

func _process(delta: float) -> void:
	var max_m = stats_component.get_stat_value("max_mana")
	var regen = stats_component.get_stat_value("mana_regen")
	
	if current_mana < max_m and regen > 0:
		current_mana += regen * delta
		current_mana = min(current_mana, max_m)
		mana_changed.emit(current_mana, max_m)

# Vérifie si le joueur a assez de mana pour lancer un sort
func has_enough_mana(amount: float) -> bool:
	return current_mana >= amount

# Consomme le mana et retourne vrai si le mana a été consommé avec succès
func use_mana(amount: float) -> bool:
	if has_enough_mana(amount):
		current_mana -= amount
		mana_changed.emit(current_mana, stats_component.get_stat_value("max_mana"))
		return true
	return false

# Si le joueur équipe un objet qui modifie son max_mana
func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_mana":
		var difference = new_value - _known_max_mana
		
		# Si on gagne du mana max, on donne ce mana instantanément
		if difference > 0:
			current_mana += difference
			
		current_mana = min(current_mana, new_value)
		_known_max_mana = new_value
		mana_changed.emit(current_mana, new_value)
