class_name Stat
extends RefCounted

var base_value: float
var modifiers: Array[StatModifier] = []

func _init(default_value: float = 0.0):
	base_value = default_value

# Ajouter un buff/debuff
func add_modifier(modifier: StatModifier) -> void:
	modifiers.append(modifier)

# Retirer un buff/debuff grâce à son ID
func remove_modifier(modifier_id: String) -> void:
	# On parcourt la liste à l'envers pour pouvoir supprimer 
	# des éléments sans casser l'ordre du tableau
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].id == modifier_id:
			modifiers.remove_at(i)

# La fonction magique qui calcule la valeur finale
func get_value() -> float:
	var final_value = base_value
	var percent_multiplier = 0.0
	
	for mod in modifiers:
		if mod.type == StatModifier.Type.FLAT:
			# Ajout brut (ex: +10 dégâts)
			final_value += mod.value
		elif mod.type == StatModifier.Type.PERCENT:
			# Ajout en pourcentage (ex: +0.20 pour 20%)
			percent_multiplier += mod.value
			
	# On applique le pourcentage total à la fin
	return final_value * (1.0 + percent_multiplier)
